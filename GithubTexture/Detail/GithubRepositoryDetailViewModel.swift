//
//  GithubRepositoryDetailViewModel.swift
//  GithubTexture
//
//  Created by Bogdan Redkin on 10.08.2022.
//

import AsyncDisplayKit
import Combine
import Foundation
import UIKit

final class GithubRepositoryDetailViewModel {
    private let readmeResponse: ReadmeResponse
    private let searchItem: SearchItem

    init(readmeResponse: ReadmeResponse, searchItem: SearchItem) {
        self.readmeResponse = readmeResponse
        self.searchItem = searchItem
    }

    var infoAttributedString: NSAttributedString {
        let string = NSMutableAttributedString(attributedString: nameAttributedString)
        string.append(additionalInfo)
        string.append(starsAttributedString)
        string.append(descriptionAttributedString)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        string.attributeText(in: NSRange(location: .zero, length: string.length), withTextKitParagraphStyle: paragraphStyle)
        return string
    }
    
    var nameAttributedString: NSAttributedString {
        return NSAttributedString(string: "Name: " + searchItem.fullName + "\n", attributes: [
            .font: UIFont.systemFont(ofSize: 20),
            .foregroundColor: UIColor.black
        ])
    }

    var starsAttributedString: NSAttributedString {
        return NSAttributedString(string: "\(searchItem.stargazersCount) ⭐️\n", attributes: [
            .font: UIFont.boldSystemFont(ofSize: 17),
            .foregroundColor: UIColor.black
        ])
    }

    var additionalInfo: NSAttributedString {
        let mutableString = NSMutableAttributedString(string: "Issues: \(searchItem.openIssuesCount)\n")
        if let language = searchItem.language {
            mutableString.append(NSAttributedString(string: "Language: \(language)\n"))
        }
        mutableString.append(NSAttributedString(string: "Forks: \(searchItem.forks)\n"))
        mutableString.append(NSAttributedString(string: "Size: \(searchItem.size)\n"))
        mutableString.setAttributes([
            .font: UIFont.monospacedSystemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: UIColor.black
        ], range: NSRange(location: .zero, length: mutableString.length))
        return mutableString
    }

    var descriptionAttributedString: NSAttributedString {
        return NSAttributedString(string: searchItem.itemDescription ?? "", attributes: [
            .font: UIFont.monospacedSystemFont(ofSize: 17, weight: .medium),
            .foregroundColor: UIColor.lightGray
        ])
    }

    var readmeAttributedString: NSAttributedString? {
        guard
            let data = Data(base64Encoded: readmeResponse.content.filter { !$0.isWhitespace }),
            var readmeString = String(data: data, encoding: .utf8),
            let htmlUrl = readmeResponse.htmlURL,
            let url = URL(string: htmlUrl)?.deletingLastPathComponent()
        else { return nil }

        let htmlRegex = "<[^>]*>"
        guard let htmlRegex = try? NSRegularExpression(pattern: htmlRegex, options: .anchorsMatchLines) else { return nil }
        let stringRange = NSRange(location: .zero, length: readmeString.count)
        let htmlMatches = htmlRegex.matches(in: readmeString, range: stringRange)
            .map({ NSString(string: readmeString).substring(with: $0.range) })

        if #available(iOS 15, *) {
            for match in htmlMatches {
                readmeString = readmeString.replacingOccurrences(of: match, with: "")
            }
            readmeString = readmeString.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let mdString = try? NSAttributedString(
                markdown: readmeString,
                options: .init(
                    allowsExtendedAttributes: true,
                    interpretedSyntax: .inlineOnlyPreservingWhitespace,
                    failurePolicy: .throwError,
                    languageCode: Locale.current.languageCode
                ),
                baseURL: url
            )

            return mdString
        } else {
            readmeString = htmlMatches.joined(separator: "")
            readmeString = readmeString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard
                !readmeString.isEmpty,
                let readmeData = readmeString.data(using: .utf8)
            else { return nil }
            
            let htmlString = try? NSAttributedString(
                data: readmeData,
                options: [.documentType: NSAttributedString.DocumentType.html],
                documentAttributes: nil
            )
            return htmlString
        }
    }
}
