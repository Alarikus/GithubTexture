//
//  GithubSearchViewController.swift
//  GithubTexture
//
//  Created by Bogdan Redkin on 04.08.2022.
//

import AsyncDisplayKit
import Combine
import Foundation
import UIKit

final class GithubSearchViewController: ASDKViewController<ASTableNode> {
    private enum Constants {
        static let authButtonWidth: CGFloat = 150
        static let activityIndicatorWidth: CGFloat = 100
        static let leadingScreensForBatching: CGFloat = 3
    }

    private lazy var activityIndicator: ASDisplayNode = {
        let activityIndicator = ASDisplayNode()
        activityIndicator.setViewBlock {
            let view = UIActivityIndicatorView()
            view.hidesWhenStopped = true
            return view
        }
        activityIndicator.style.preferredSize = CGSize(width: Constants.activityIndicatorWidth, height: Constants.activityIndicatorWidth)
        return activityIndicator
    }()

    private var viewModel: GithubSearchViewModel
    private var bindings = Set<AnyCancellable>()

    init(viewModel: GithubSearchViewModel) {
        self.viewModel = viewModel
        super.init(node: ASTableNode())
        node.backgroundColor = .white
        node.automaticallyManagesSubnodes = true
        node.layoutSpecBlock = { _, _ in
            let centerLayout = ASCenterLayoutSpec(
                centeringOptions: .XY,
                sizingOptions: .minimumXY,
                child:
                ASInsetLayoutSpec(
                    insets: UIEdgeInsets(
                        top: -Constants.activityIndicatorWidth,
                        left: .zero,
                        bottom: .zero,
                        right: .zero
                    ),
                    child: self.activityIndicator
                )
            )
            return centerLayout
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigationBar()
        node.delegate = self
        node.dataSource = viewModel
        node.leadingScreensForBatching = Constants.leadingScreensForBatching
        setupInitialBindings()
    }

    private func setupInitialBindings() {
        viewModel.$searchResultDataSource
            .receive(on: DispatchQueue.main)
            .scan(([SearchItem](), [IndexPath]())) {
                guard $0.0.count < $1.count else { return ($1, []) }
                let indexes = ($0.0.count ..< $1.count).map { IndexPath(row: $0, section: .zero) }
                return ($1, indexes)
            }
            .sink { [weak self] _, indexes in
                if indexes.isEmpty {
                    self?.node.reloadData()
                } else {
                    self?.node.insertRows(at: indexes, with: .none)
                }
                self?.viewModel.batchContext?.completeBatchFetching(true)
            }
            .store(in: &bindings)

        viewModel.$showLoadingAnimation
            .receive(on: RunLoop.main)
            .sink { [weak self] showLoading in
                if showLoading {
                    self?.showReloadAnimation()
                } else {
                    self?.stopReloadAnimation()
                }
            }
            .store(in: &bindings)
    }

    private func configureNavigationBar() {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.automaticallyShowsSearchResultsController = false
        searchController.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = searchController
    }

    private func showReloadAnimation() {
        (activityIndicator.view as? UIActivityIndicatorView)?.startAnimating()
    }

    private func stopReloadAnimation() {
        (activityIndicator.view as? UIActivityIndicatorView)?.stopAnimating()
    }
}

extension GithubSearchViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        viewModel.search(searchController.searchBar.text)
    }
}

extension GithubSearchViewController: ASTableDelegate {
    func tableNode(_ tableNode: ASTableNode, didSelectRowAt indexPath: IndexPath) {
        guard let readmeResponse = (tableNode.nodeForRow(at: indexPath) as? GithubSearchCellNode)?.viewModel.readmeResponse else { return }
        let searchItem = viewModel.searchResultDataSource[indexPath.row]
        navigationController?.pushViewController(
            GithubRepositoryDetailAssembly.assembly(readmeResponse: readmeResponse, searchItem: searchItem),
            animated: true
        )
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        navigationItem.searchController?.searchBar.endEditing(true)
    }

    func shouldBatchFetch(for tableNode: ASTableNode) -> Bool {
        let isSearchResultEmpty = viewModel.searchResultDataSource.isEmpty
        return !isSearchResultEmpty
    }

    func tableView(_ tableView: ASTableView, willBeginBatchFetchWith context: ASBatchContext) {
        viewModel.loadNextPage(context: context)
    }
}
