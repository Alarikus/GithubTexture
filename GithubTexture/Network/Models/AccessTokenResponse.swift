//
//  AccessTokenResponse.swift
//  GithubTexture
//
//  Created by Bogdan Redkin on 04.08.2022.
//

import Foundation

struct AccessTokenResponse: Codable {
    let accessToken, tokenType, scope: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
    }
}
