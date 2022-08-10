//
//  GithubRepositoryDetailViewController.swift
//  GithubTexture
//
//  Created by Bogdan Redkin on 10.08.2022.
//

import AsyncDisplayKit
import Combine
import Foundation
import UIKit
import WebKit

final class GithubRepositoryDetailViewController: ASDKViewController<ASDisplayNode> {
    
    private lazy var scrollNode: ASScrollNode = {
        let scrollNode = ASScrollNode()
        scrollNode.scrollableDirections = [.down, .up]
        scrollNode.automaticallyManagesSubnodes = true
        scrollNode.automaticallyManagesContentSize = true

        let infoTextNode = ASTextNode()
        infoTextNode.attributedText = viewModel.infoAttributedString

        let readmeTextNode = ASTextNode()
        DispatchQueue.global().async {
            let atrtibutedReadme = self.viewModel.readmeAttributedString
            DispatchQueue.main.async {
                readmeTextNode.attributedText = atrtibutedReadme
            }
        }
        scrollNode.layoutSpecBlock = { _, _ in
            let headerLayout = ASStackLayoutSpec(
                direction: .vertical,
                spacing: 25,
                justifyContent: .start,
                alignItems: .start,
                children: [infoTextNode, readmeTextNode]
            )

            return ASInsetLayoutSpec(
                insets: UIEdgeInsets(top: .zero, left: 12, bottom: 0, right: 12),
                child: headerLayout
            )
        }
        return scrollNode
    }()

    private var viewModel: GithubRepositoryDetailViewModel

    init(viewModel: GithubRepositoryDetailViewModel) {
        self.viewModel = viewModel
        super.init(node: ASDisplayNode())
        node.backgroundColor = .white
        node.automaticallyManagesSubnodes = true

        node.layoutSpecBlock = { _, _ in
            ASStackLayoutSpec(
                direction: .vertical,
                spacing: .zero,
                justifyContent: .start,
                alignItems: .start,
                children: [self.scrollNode]
            )
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
