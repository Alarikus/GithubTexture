//
//  GithubSearchAssembly.swift
//  GithubTexture
//
//  Created by Bogdan Redkin on 09.08.2022.
//

import Foundation
import UIKit

enum GithubSearchAssembly {
    static func assembly(offline: Bool = false) -> UIViewController {
        let githubRepository: GithubRepository = {
            if offline {
                return LocalGithubRepository()
            } else {
                return RemoteGithubRepository(
                    credentialsStorage: KeychainCredentialsStorage(),
                    networkProvider: RemoteNetworkProvider(),
                    searchResultStorage: LocalGithubRepository()
                )
            }
        }()

        let viewModel = GithubSearchViewModel(githubRepository: githubRepository)
        return GithubSearchViewController(viewModel: viewModel)
    }
}
