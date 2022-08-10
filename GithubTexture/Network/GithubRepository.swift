//
//  GithubRepository.swift
//  GithubTexture
//
//  Created by Bogdan Redkin on 04.08.2022.
//

import Combine
import Foundation

private enum Constants {
    static let githubApiHost = "https://api.github.com"
    static let githubHost = "https://github.com"
}

public enum Path: String {
    case authorizePath = "/login/oauth/authorize"
    case accessTokenPath = "/login/oauth/access_token"
    case userPath = "/user"
    case searchPath = "/search/repositories"
    case reposPath = "/repos"
}

protocol GithubRepository {
    func userInfo() -> AnyPublisher<User, Error>
    func search(query: String, page: Int, itemsCount: Int) -> AnyPublisher<SearchResponse, Error>
    func authenticate(code: String) -> AnyPublisher<AccessTokenResponse, Error>
    func buildAuthorizationURL() -> URL?
    func readme(owner: String, repo: String) -> AnyPublisher<ReadmeResponse, Error>
}

extension GithubRepository {
    func userInfo() -> AnyPublisher<User, Error> {
        return Fail(error: NetworkError.notImplemented).eraseToAnyPublisher()
    }

    func authenticate(code: String) -> AnyPublisher<AccessTokenResponse, Error> {
        return Fail(error: NetworkError.notImplemented).eraseToAnyPublisher()
    }

    func buildAuthorizationURL() -> URL? {
        return nil
    }

    func url(_ path: Path, pathComponents: String...) -> String {
        var base: String {
            switch path {
            case .authorizePath,
                 .accessTokenPath:
                return Constants.githubHost + path.rawValue
            case .userPath,
                 .searchPath,
                 .reposPath:
                return Constants.githubApiHost + path.rawValue
            }
        }
        var url = URL(string: base)
        for pathComponent in pathComponents {
            url?.appendPathComponent(pathComponent)
        }
        return url?.absoluteString ?? base
    }
}

class RemoteGithubRepository: GithubRepository {
    private let searchResultStorage: ResultStorage?
    private let credentialsStorage: CredentialsStorage
    private let networkProvider: NetworkProvider

    init(credentialsStorage: CredentialsStorage, networkProvider: NetworkProvider, searchResultStorage: ResultStorage? = nil) {
        self.credentialsStorage = credentialsStorage
        self.networkProvider = networkProvider
        self.searchResultStorage = searchResultStorage
    }

    func userInfo() -> AnyPublisher<User, Error> {
        if let authHeader = authHeader() {
            return networkProvider.request(url: url(.userPath), responseDecodable: User.self, headers: authHeader)
        } else {
            return Fail(error: NetworkError.needAuthorization).eraseToAnyPublisher()
        }
    }

    func search(query: String, page: Int, itemsCount: Int) -> AnyPublisher<SearchResponse, Error> {
        if let authHeader = authHeader() {
            return networkProvider.request(
                url: url(.searchPath),
                cancelPreviousTask: true,
                responseDecodable: SearchResponse.self,
                queryParameters: [
                    "q": query,
                    "page": "\(page)",
                    "per_page": "\(itemsCount)"
                ],
                headers: authHeader
            ).compactMap { [weak self] in
                self?.searchResultStorage?.saveSearchResponse(query: query, response: $0)
                return $0
            }.eraseToAnyPublisher()
        } else {
            return Fail(error: NetworkError.needAuthorization).eraseToAnyPublisher()
        }
    }

    func readme(owner: String, repo: String) -> AnyPublisher<ReadmeResponse, Error> {
        if let authHeader = authHeader() {
            let url = url(.reposPath, pathComponents: owner, repo, "readme")

            return networkProvider.request(
                url: url,
                responseDecodable: ReadmeResponse.self,
                headers: authHeader
            ).compactMap { [weak self] in
                self?.searchResultStorage?.saveReadme(readmeResponse: $0)
                return $0
            }.eraseToAnyPublisher()
        } else {
            return Fail(error: NetworkError.needAuthorization).eraseToAnyPublisher()
        }
    }

    func authenticate(code: String) -> AnyPublisher<AccessTokenResponse, Error> {
        return networkProvider.request(
            url: url(.accessTokenPath),
            responseDecodable: AccessTokenResponse.self,
            queryParameters: [
                "client_id": credentialsStorage.githubClientId,
                "client_secret": credentialsStorage.githubClientSecret,
                "code": code
            ],
            headers: ["Accept": "application/json"]
        )
    }

    func buildAuthorizationURL() -> URL? {
        var urlComponents = URLComponents(string: url(.authorizePath))
        let params: QueryParameters = [
            "client_id": credentialsStorage.githubClientId,
            "redirect_uri": "githubtexture://github-auth-callback/"
        ]
        urlComponents?.queryItems = params.queryParameters
        return urlComponents?.url
    }

    private func authHeader() -> HTTPHeaders? {
        guard let token = credentialsStorage.getAuthToken() else { return nil }
        return ["Authorization": "Bearer " + token]
    }
}
