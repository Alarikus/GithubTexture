//
//  SearchResultStorage.swift
//  GithubTexture
//
//  Created by Bogdan Redkin on 10.08.2022.
//

import Combine
import Foundation

protocol ResultStorage {
    func saveSearchResponse(query: String, response: SearchResponse)
    func saveReadme(readmeResponse: ReadmeResponse)
}

class LocalGithubRepository: GithubRepository, ResultStorage {
    private let saveSearchResultQueue = DispatchQueue(label: "searchResultStorage.searchResponse")
    private var savedResponses: [String: SearchResponse] = [:]
    
    init() {
        saveSearchResultQueue.async {
            UserDefaults.standard.stringArray(forKey: "saved_responses")?.forEach { key in
                if
                    let savedResponseString = UserDefaults.standard.string(forKey: key),
                    let data = savedResponseString.data(using: .utf8) {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    if let savedResponse = try? decoder.decode(SearchResponse.self, from: data) {
                        self.savedResponses[key] = savedResponse
                    }
                }
            }
            print("saved response keys: \(self.savedResponses.keys)")
        }
    }

    func saveSearchResponse(query: String, response: SearchResponse) {
        saveSearchResultQueue.async { [weak self] in
            guard let self = self else { return }
            if let savedResponse = self.savedResponses[query] {
                var savedItems = savedResponse.items
                savedItems.append(contentsOf: response.items)
                self.savedResponses[query]?.items = savedItems
            } else {
                self.savedResponses[query] = response
            }

            let mappedResponses = self.savedResponses.compactMap { key, value -> (String, String)? in
                let encoder = JSONEncoder()
                if
                    let encodedValue = try? encoder.encode(value),
                    let encodedString = String(data: encodedValue, encoding: .utf8) {
                    return (key, encodedString)
                } else {
                    return nil
                }
            }

            var keys: [String] = []

            if let savedKeysArray = UserDefaults.standard.stringArray(forKey: "saved_responses") {
                keys = savedKeysArray
            }

            mappedResponses.forEach { key, value in
                keys.append(key)
                UserDefaults.standard.set(value, forKey: key)
            }

            let uniqueKeys = Array(Set(keys))
            UserDefaults.standard.set(uniqueKeys, forKey: "saved_responses")
        }
    }

    func saveReadme(readmeResponse: ReadmeResponse) {
        guard
            let linksSelf = readmeResponse.links.linksSelf,
            let readmeUrl = URL(string: linksSelf)
        else { return }

        let owner = readmeUrl.pathComponents[2]
        let repo = readmeUrl.pathComponents[3]
        let keyUrl = url(.reposPath, pathComponents: owner, repo, "readme")
        
        if UserDefaults.standard.value(forKey: keyUrl) == nil {
            let encoder = JSONEncoder()
            if
                let encodedValue = try? encoder.encode(readmeResponse),
                let encodedString = String(data: encodedValue, encoding: .utf8) {
                UserDefaults.standard.set(encodedString, forKey: keyUrl)
            }
        }
    }

    func search(query: String, page: Int, itemsCount: Int) -> AnyPublisher<SearchResponse, Error> {
        return Future<SearchResponse, Error> { [weak self] promise in
            guard let self = self else { return }
            self.saveSearchResultQueue.sync {
                if let savedResponse = self.savedResponses[query] {
                    promise(.success(savedResponse))
                } else {
                    promise(.failure(URLError(.cannotDecodeRawData)))
                }
            }
        }.eraseToAnyPublisher()
    }

    func readme(owner: String, repo: String) -> AnyPublisher<ReadmeResponse, Error> {
        return Future<ReadmeResponse, Error> { [weak self] promise in
            guard let self = self else { return }
            let url = self.url(.reposPath, pathComponents: owner, repo, "readme")
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            if
                let savedReadmeString = UserDefaults.standard.value(forKey: url) as? String,
                let data = savedReadmeString.data(using: .utf8),
                let savedReadmeResponse = try? decoder.decode(ReadmeResponse.self, from: data) {
                promise(.success(savedReadmeResponse))
            } else {
                promise(.failure(URLError(.cannotDecodeRawData)))
            }
        }.eraseToAnyPublisher()
    }
}
