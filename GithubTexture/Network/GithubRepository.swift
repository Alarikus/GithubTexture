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
