//
//  ErrorResponse.swift
//  GithubTexture
//
//  Created by Bogdan Redkin on 10.08.2022.
//

import Foundation

struct ErrorResponse: Codable, Error {
    let message: String
}
