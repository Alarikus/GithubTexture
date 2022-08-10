//
//  ReadmeResponse.swift
//  GithubTexture
//
//  Created by Bogdan Redkin on 09.08.2022.
//

import Foundation

struct ReadmeResponse: Codable {
    let name, path, sha: String
    let size: Int
    let url: String
    let htmlURL, gitURL, downloadURL, target: String?
    let type, content, encoding: String
    let links: Links

    enum CodingKeys: String, CodingKey {
        case name, path, sha, size, url
        case htmlURL = "html_url"
        case gitURL = "git_url"
        case downloadURL = "download_url"
        case type, content, encoding, target
        case links = "_links"
    }
}

struct Links: Codable {
    let linksSelf: String?
    let git: String?
    let html: String?

    enum CodingKeys: String, CodingKey {
        case linksSelf = "self"
        case git, html
    }
}
