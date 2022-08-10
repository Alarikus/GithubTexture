//
//  GithubSearchViewModel.swift
//  GithubTexture
//
//  Created by Bogdan Redkin on 09.08.2022.
//

import AsyncDisplayKit
import Combine
import Foundation

final class GithubSearchViewModel: NSObject {
    
    private enum Constants {
        static let initialPage: Int = 1
        static let searchQueueLabel: String = "GithubSearchViewModel"
        static let searchTextPublisherDebounce: Double = 0.3
        static let pageItemsCount: Int = 100
    }

    @Published var searchText: String = ""
    @Published var searchResultDataSource: [SearchItem] = []
    @Published var showLoadingAnimation: Bool = false
    var batchContext: ASBatchContext?
    
    private var currentPage = Constants.initialPage
    private var githubRepository: GithubRepository
    private var bindings = Set<AnyCancellable>()
    private var isNewPageFetching: Bool = false
    private let searchQueue = DispatchQueue(label: Constants.searchQueueLabel)

    init(githubRepository: GithubRepository) {
        self.githubRepository = githubRepository
        super.init()
        $searchText
            .dropFirst(1)
            .debounce(for: .seconds(Constants.searchTextPublisherDebounce), scheduler: searchQueue)
            .sink(receiveValue: fetchSearchResult(searchText:))
            .store(in: &bindings)
    }

    func search(_ text: String?) {
        guard text != searchText else { return }
        searchResultDataSource.removeAll()
        currentPage = Constants.initialPage
        guard let text = text, !text.isEmpty else {
            showLoadingAnimation = false
            return
        }
        showLoadingAnimation = true
        searchText = text
    }

    func loadNextPage(context: ASBatchContext) {
        DispatchQueue.main.async {
            guard !self.isNewPageFetching, !self.searchText.isEmpty else {
                context.completeBatchFetching(true)
                return
            }
            self.batchContext = context
            self.isNewPageFetching = true
            self.currentPage += 1
            self.searchQueue.async { [weak self] in
                guard let self = self else { return }
                self.fetchSearchResult(searchText: self.searchText)
            }
        }
    }

    private func fetchSearchResult(searchText: String) {
        print("search repositories: \(searchText) page: \(currentPage)")
        githubRepository
            .search(query: searchText, page: currentPage, itemsCount: Constants.pageItemsCount)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                switch completion {
                case let .failure(error):
                    if let urlError = error as? URLError {
                        if urlError.code != URLError(.cancelled).code {
                            print("receive error: \(error)")
                            self?.showLoadingAnimation = false
                        }
                    }
                case .finished: break
                }
            } receiveValue: { [weak self] response in
                guard let self = self else { return }
                let resultData = response.items
                self.showLoadingAnimation = false
                if !resultData.isEmpty {
                    self.isNewPageFetching = false
                }
                if self.currentPage == Constants.initialPage {
                    self.searchResultDataSource = resultData
                } else {
                    self.searchResultDataSource.append(contentsOf: resultData)
                }
            }.store(in: &bindings)
    }
}

extension GithubSearchViewModel: ASTableDataSource {
    func numberOfSections(in tableNode: ASTableNode) -> Int {
        return 1
    }

    func tableNode(_ tableNode: ASTableNode, numberOfRowsInSection section: Int) -> Int {
        return searchResultDataSource.count
    }
    
    func tableNode(_ tableNode: ASTableNode, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
        return {
            guard self.searchResultDataSource.count > indexPath.row else { return ASCellNode() }
            let node =
                GithubSearchCellNode(viewModel: GithubSearchCellViewModel(
                    githubRepository: self.githubRepository,
                    searchItem: self.searchResultDataSource[indexPath.row]
                ))
            return node
        }
    }
}
