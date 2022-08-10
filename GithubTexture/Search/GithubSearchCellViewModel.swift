//
//  GithubSearchCellViewModel.swift
//  GithubTexture
//
//  Created by Bogdan Redkin on 09.08.2022.
//

import Combine
import Foundation

final class GithubSearchCellViewModel: Hashable {
    private enum Constants {
        static let reeadmeQueueLabel: String = "GithubSearchCellViewModel"
        static let htmlImageRegexp: String = #""([^"]*?\.(jpg|png|gif|jpeg))"|'([^']*?\.(jpg|png|gif|jpeg))'"#
        static let markdownImageRegexp: String = #"\!\[[^\]]*\]\([^\)]*\)"#
        static let githubHtmlHost: String = "https://github.com"
        static let githubUserContentHost: String = "https://raw.githubusercontent.com"
        static let maxDescriptionLength: Int = 350
    }

    private(set) var searchItem: SearchItem
    private(set) var readmeResponse: ReadmeResponse?
    private var bindings = Set<AnyCancellable>()

    @Published var imageUrl: String?
    
    var name: String {
        return searchItem.fullName
    }

    var description: String {
        if let description = searchItem.itemDescription {
            return String(description.prefix(Constants.maxDescriptionLength))
        } else {
            return ""
        }
    }

    var stars: String {
        return "\(searchItem.stargazersCount) ⭐️"
    }

    var mainLanguage: String {
        if let language = searchItem.language {
            return "Language: \(language)"
        } else {
            return ""
        }
    }

    init(githubRepository: GithubRepository, searchItem: SearchItem) {
        self.searchItem = searchItem
        githubRepository.readme(owner: searchItem.owner.login, repo: searchItem.name)
            .receive(on: DispatchQueue(label: Constants.reeadmeQueueLabel))
            .sink { _ in
            } receiveValue: { [weak self] response in
                guard let self = self else { return }
                self.readmeResponse = response
                var imageUrl = self.findImagUrl(readmeResponse: response)
                if var url = imageUrl {
                    if
                        let readmeHtmlLink = response.htmlURL,
                        let readmeHtmlUrl = URL(string: readmeHtmlLink),
                        let readmeDownloadLink = response.downloadURL,
                        let readmeDownloadUrl = URL(string: readmeDownloadLink) {
                        let repoHtmlUrl = readmeHtmlUrl.deletingLastPathComponent()
                        let repoDownloadUrl = readmeDownloadUrl.deletingLastPathComponent()
                        if url.contains(repoHtmlUrl.absoluteString) {
                            url = url.replacingOccurrences(of: repoHtmlUrl.absoluteString, with: repoDownloadUrl.absoluteString)
                        }
                        if !url.contains("http") {
                            url = repoDownloadUrl.absoluteString + url
                        }
                        // Replacement in case of image url in another repository
                        if url.contains(Constants.githubHtmlHost), url.contains("blob") {
                            url = url.replacingOccurrences(of: Constants.githubHtmlHost, with: Constants.githubUserContentHost)
                                .replacingOccurrences(of: "blob", with: "")
                        }
                        url = url.replacingOccurrences(of: "//", with: "/")
                        if url.contains("svg") {
                            imageUrl = nil
                        } else {
                            imageUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                        }
                    }
                }
                self.imageUrl = imageUrl
            }
            .store(in: &bindings)
    }

    private func findImagUrl(readmeResponse response: ReadmeResponse) -> String? {
        autoreleasepool {
            guard
                let data = Data(base64Encoded: response.content.filter { !$0.isWhitespace }),
                let readmeString = String(data: data, encoding: .utf8)
            else { return nil }

            let stringRange = NSRange(location: .zero, length: readmeString.count)
            guard let htmlRegex = try? NSRegularExpression(pattern: Constants.htmlImageRegexp, options: .anchorsMatchLines) else { return nil }
            let htmlMatches = htmlRegex.matches(in: readmeString, range: stringRange)
            guard let mdRegex = try? NSRegularExpression(pattern: Constants.markdownImageRegexp, options: .anchorsMatchLines) else { return nil }
            let mdMatches = mdRegex.matches(in: readmeString, range: stringRange)

            let nsReadmeString = NSString(string: readmeString)

            func extractUrlFromHtmlString(_ string: String) -> String {
                return string.replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "'", with: "")
            }

            func extractUrlFromMdString(_ string: String) -> String {
                if string.contains("]("), string.contains(")") {
                    return string.components(separatedBy: "](")[1].components(separatedBy: ")")[0]
                }
                return string
            }

            if let htmlImageMatch = htmlMatches.first {
                if let mdImageMatch = mdMatches.first {
                    if htmlImageMatch.range.location < mdImageMatch.range.location {
                        return extractUrlFromHtmlString(nsReadmeString.substring(with: htmlImageMatch.range))
                    } else {
                        return extractUrlFromMdString(nsReadmeString.substring(with: mdImageMatch.range))
                    }
                }
                return extractUrlFromHtmlString(nsReadmeString.substring(with: htmlImageMatch.range))
            }

            if let mdImageMatch = mdMatches.first {
                return extractUrlFromMdString(nsReadmeString.substring(with: mdImageMatch.range))
            }
            return nil
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(searchItem.url)
    }

    static func == (lhs: GithubSearchCellViewModel, rhs: GithubSearchCellViewModel) -> Bool {
        return lhs.searchItem.url == rhs.searchItem.url
    }
}
