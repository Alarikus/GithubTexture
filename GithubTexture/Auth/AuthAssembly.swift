//
//  AuthAssembly.swift
//  GithubTexture
//
//  Created by Bogdan Redkin on 10.08.2022.
//

import Combine
import Foundation
import UIKit

enum AuthAssembly {
    typealias URLContextSubject = PassthroughSubject<Set<UIOpenURLContext>, Never>

    static func assembly(urlContextSubject: URLContextSubject) -> UIViewController {
        let keychainCredentialsStorage = KeychainCredentialsStorage()
        let viewModel = AuthViewModel(
            githubRepository: RemoteGithubRepository(
                credentialsStorage: keychainCredentialsStorage,
                networkProvider: RemoteNetworkProvider()
            ),
            credentialsStorage: keychainCredentialsStorage,
            urlContextSubject: urlContextSubject
        )
        return AuthViewController(viewModel: viewModel)
    }
}
