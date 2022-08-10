//
//  SearchResponse.swift
//  GithubTexture
//
//  Created by Bogdan Redkin on 04.08.2022.
//

import Foundation

struct SearchResponse: Codable {
    let totalCount: Int
    let incompleteResults: Bool
    var items: [SearchItem]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case incompleteResults = "incomplete_results"
        case items
    }
}
