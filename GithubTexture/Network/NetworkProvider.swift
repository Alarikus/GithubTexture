//
//  Network.swift
//  GithubTexture
//
//  Created by Bogdan Redkin on 04.08.2022.
//

import Combine
import Foundation

enum Method: String {
    case GET
    case POST
}

struct HTTPHeaders {
    let headers: [String: String]
}

struct QueryParameters {
    let queryParameters: [URLQueryItem]
}

extension QueryParameters: ExpressibleByDictionaryLiteral {
    init(dictionaryLiteral elements: (String, String)...) {
        self.queryParameters = elements.map { URLQueryItem(name: $0.0, value: $0.1) }
    }
}

extension HTTPHeaders: ExpressibleByDictionaryLiteral {
    init(dictionaryLiteral elements: (String, String)...) {
        self.headers = elements.reduce([String: String]()) { output, input -> [String: String] in
            var dict = output
            dict[input.0] = input.1
            return dict
        }
    }
}

enum NetworkError: Error {
    case incorrectUrl
    case requestError
    case parsingError
    case needAuthorization
    case notImplemented
}

protocol NetworkProvider {
    func request<T: Decodable>(
        url: String,
        cancelPreviousTask: Bool,
        method: Method,
        responseDecodable: T.Type,
        queryParameters parameters: QueryParameters,
        headers: HTTPHeaders
    ) -> AnyPublisher<T, Error>
}

extension NetworkProvider {
    func request<T>(
        url: String,
        cancelPreviousTask: Bool = false,
        method: Method = .GET,
        responseDecodable: T.Type,
        queryParameters parameters: QueryParameters = [:],
        headers: HTTPHeaders = [:]
    ) -> AnyPublisher<T, Error> where T: Decodable {
        return self.request(
            url: url,
            cancelPreviousTask: cancelPreviousTask,
            method: method,
            responseDecodable: responseDecodable,
            queryParameters: parameters,
            headers: headers
        )
    }
}

class RemoteNetworkProvider: NetworkProvider {
    private var currentTask: URLSessionTask?

    func request<T>(
        url: String,
        cancelPreviousTask: Bool = false,
        method: Method = .GET,
        responseDecodable: T.Type,
        queryParameters parameters: QueryParameters = [:],
        headers: HTTPHeaders = [:]
    ) -> AnyPublisher<T, Error> where T: Decodable {
        let subject = PassthroughSubject<T, Error>()

        if cancelPreviousTask {
            currentTask?.cancel()
        }

        var urlComponents = URLComponents(string: url)
        if !parameters.queryParameters.isEmpty {
            urlComponents?.queryItems = parameters.queryParameters
        }
        guard let url = urlComponents?.url else {
            subject.send(completion: .failure(NetworkError.incorrectUrl))
            return subject.eraseToAnyPublisher()
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.allHTTPHeaderFields = headers.headers

        let newTask = URLSession.shared.dataTask(with: request, completionHandler: { [weak self] data, response, error in
            if let error = error {
                subject.send(completion: .failure(error))
                return
            }

            guard let data = data else {
                subject.send(completion: .failure(NetworkError.parsingError))
                return
            }

            if let decodedError = try? decoder.decode(ErrorResponse.self, from: data) {
                subject.send(completion: .failure(decodedError))
                return
            }

            guard
                let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200
            else {
                subject.send(completion: .failure(URLError(.badServerResponse)))
                return
            }

            guard let decoded = try? decoder.decode(T.self, from: data)
            else {
                subject.send(completion: .failure(NetworkError.parsingError))
                return
            }

            subject.send(decoded)
            if cancelPreviousTask {
                self?.currentTask = nil
            }
        })
        newTask.resume()

        if cancelPreviousTask {
            currentTask = newTask
        }
        return subject.eraseToAnyPublisher()
    }
}
