//
//  GithubRepositoryDetailAssembly.swift
//  GithubTexture
//
//  Created by Bogdan Redkin on 10.08.2022.
//

import Foundation
import UIKit

enum GithubRepositoryDetailAssembly {
    static func assembly(readmeResponse: ReadmeResponse, searchItem: SearchItem) -> UIViewController {
        let viewModel = GithubRepositoryDetailViewModel(readmeResponse: readmeResponse, searchItem: searchItem)
        return GithubRepositoryDetailViewController(viewModel: viewModel)
    }
}
