//
//  CredentialsStorage.swift
//  GithubTexture
//
//  Created by Bogdan Redkin on 04.08.2022.
//

import Foundation
import Security

protocol CredentialsStorage {
    func saveAuthToken(token: String)
    func getAuthToken() -> String?
    var githubClientId: String { get }
    var githubClientSecret: String { get }
}

class KeychainCredentialsStorage: CredentialsStorage {
    private enum Constants {
        static let accessTokenService = "access-token"
        static let githubAccount = "github"
    }
        
    var githubClientId: String {
        return <#github_client_id#>
    }
    
    var githubClientSecret: String {
        return <#github_client_secret#>
    }
    
    func saveAuthToken(token: String) {
        guard let tokenData = token.data(using: .utf8) else {
            print("Error convert token to data")
            return
        }
        let query = [
            kSecValueData: tokenData,
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Constants.accessTokenService,
            kSecAttrAccount: Constants.githubAccount
        ] as CFDictionary

        var status = SecItemAdd(query, nil)

        if status == errSecDuplicateItem {
            let query = [
                kSecAttrService: Constants.accessTokenService,
                kSecAttrAccount: Constants.githubAccount,
                kSecClass: kSecClassGenericPassword
            ] as CFDictionary

            let attributesToUpdate = [kSecValueData: tokenData] as CFDictionary

            status = SecItemUpdate(query, attributesToUpdate)
        }

        if status != errSecSuccess {
            print("Keychain item update error: \(status)")
        }
    }
    
    func getAuthToken() -> String? {
        let query = [
            kSecAttrService: Constants.accessTokenService,
            kSecAttrAccount: Constants.githubAccount,
            kSecClass: kSecClassGenericPassword,
            kSecReturnData: true
        ] as CFDictionary
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)
        
        if status != errSecSuccess {
            print("Token not found in keychain")
            return nil
        }
        
        guard
            let result = result as? Data,
            let resultString = String(data: result, encoding: .utf8)
        else {
            print("Can't convert token data to string")
            return nil
        }

        return resultString
    }
}
