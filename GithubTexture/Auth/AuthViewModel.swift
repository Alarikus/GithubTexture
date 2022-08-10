//
//  AuthViewModel.swift
//  GithubTexture
//
//  Created by Bogdan Redkin on 09.08.2022.
//

import AsyncDisplayKit
import Combine
import Foundation
import Network

final class AuthViewModel {
    private enum Constants {
        static let callbackUrlScheme: String = "githubtexture"
        static let authQueueLabel: String = "AuthViewModel"
    }

    enum State {
        case unauthorized
        case authorizing(authUrl: URL)
        case authorized
        case offline
        case loading
        case error(message: String)
    }

    @Published var currentState: State = .loading

    private let githubRepository: GithubRepository
    private let credentialsStorage: CredentialsStorage
    private let urlContextSubject: AuthAssembly.URLContextSubject
    private let monitor = NWPathMonitor()

    private let authQueue = DispatchQueue(label: Constants.authQueueLabel)
    private var bindings = Set<AnyCancellable>()

    init(
        githubRepository: GithubRepository,
        credentialsStorage: CredentialsStorage,
        urlContextSubject: AuthAssembly.URLContextSubject
    ) {
        self.githubRepository = githubRepository
        self.credentialsStorage = credentialsStorage
        self.urlContextSubject = urlContextSubject
        checkInternetConnection()
        setupBindings()
    }

    func authButtonTapped() {
        guard let authUrl = githubRepository.buildAuthorizationURL() else { return }
        currentState = .authorizing(authUrl: authUrl)
    }

    private func setupBindings() {
        urlContextSubject.receive(on: authQueue)
            .sink(receiveValue: { [weak self] URLContexts in
                guard
                    let self = self,
                    let url = URLContexts.first?.url,
                    url.scheme == Constants.callbackUrlScheme,
                    let components = URLComponents(string: url.absoluteString),
                    let codeQueryComponent = components.queryItems?.filter({ $0.name == "code" }).first,
                    let code = codeQueryComponent.value
                else {
                    self?.currentState = .error(message: "Authentication code didn't parsed")
                    self?.currentState = .unauthorized
                    return
                }
                self.githubRepository
                    .authenticate(code: code)
                    .receive(on: self.authQueue)
                    .sink(receiveCompletion: { completion in
                        switch completion {
                        case let .failure(error):
                            if let decodedError = error as? ErrorResponse {
                                self.currentState = .error(message: decodedError.message)
                                return
                            }
                            
                            self.currentState = .error(message: "Authentication error: \(error.localizedDescription)")
                        default: break
                        }
                    }, receiveValue: { authResponse in
                        self.credentialsStorage.saveAuthToken(token: authResponse.accessToken)
                        self.checkAuthenticationStatus()
                    })
                    .store(in: &self.bindings)
            })
            .store(in: &bindings)
    }

    private func checkInternetConnection() {
        monitor.pathUpdateHandler = { [weak self] path in
            switch path.status {
            case .satisfied:
                self?.checkAuthenticationStatus()
            case .requiresConnection,
                 .unsatisfied:
                self?.currentState = .offline
            @unknown default:
                break
            }
        }
        monitor.start(queue: authQueue)
    }

    private func checkAuthenticationStatus() {
        githubRepository.userInfo()
            .receive(on: authQueue)
            .sink { [weak self] completion in
                switch completion {
                case let .failure(error):
                    if let networkError = error as? NetworkError,
                       networkError == .needAuthorization {
                        self?.currentState = .unauthorized
                        return
                    }
                    
                    if let decodedError = error as? ErrorResponse {
                        self?.currentState = .error(message: decodedError.message)
                        return
                    }
                    
                    self?.currentState = .error(message: error.localizedDescription)
                default: break
                }
            } receiveValue: { [weak self] _ in
                self?.currentState = .authorized
            }.store(in: &bindings)
    }
}
