//
//  GithubSearchCellNode.swift
//  GithubTexture
//
//  Created by Bogdan Redkin on 09.08.2022.
//

import AsyncDisplayKit
import Combine
import UIKit

final class GithubSearchCellNode: ASCellNode, ASNetworkImageNodeDelegate {
    private let name: ASTextNode = .init()
    private let language: ASTextNode = .init()
    private let stars: ASTextNode = .init()
    private let repositoryDescription: ASTextNode = .init()
    private let image: ASNetworkImageNode = .init()

    private var bindings = Set<AnyCancellable>()
    var viewModel: GithubSearchCellViewModel
    
    init(viewModel: GithubSearchCellViewModel) {
        self.viewModel = viewModel
        super.init()
        self.automaticallyManagesSubnodes = true
        self.stars.attributedText = NSAttributedString(string: viewModel.stars, attributes: [
            .font: UIFont.boldSystemFont(ofSize: 17),
            .foregroundColor: UIColor.black
        ])
        self.name.attributedText = NSAttributedString(string: viewModel.name, attributes: [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: UIColor.black
        ])
        self.repositoryDescription.attributedText = NSAttributedString(string: viewModel.description, attributes: [
            .font: UIFont.monospacedSystemFont(ofSize: 15, weight: .medium),
            .foregroundColor: UIColor.lightGray
        ])
        self.language.attributedText = NSAttributedString(string: viewModel.mainLanguage, attributes: [
            .font: UIFont.monospacedSystemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: UIColor.black
        ])
        self.image.placeholderEnabled = true
        self.image.contentMode = .scaleAspectFit
        self.image.shouldCacheImage = true
        self.image.shouldRetryImageDownload = false
        self.image.forceUpscaling = true
        self.image.delegate = self
        self.viewModel.$imageUrl
            .receive(on: DispatchQueue.main)
            .sink { [weak self] imageUrl in
                guard let self = self else { return }
                if let imageUrl = imageUrl {
                    self.image.style.preferredLayoutSize = ASLayoutSize(
                        width: .init(unit: .fraction, value: 1),
                        height: .init(unit: .points, value: 200)
                    )
                    self.setNeedsLayout()
                    self.image.setURL(URL(string: imageUrl), resetToDefault: true)
                } else {
                    self.image.style.preferredLayoutSize = ASLayoutSize(
                        width: .init(unit: .fraction, value: 1),
                        height: .init(unit: .points, value: 0)
                    )
                    self.setNeedsLayout()
                }
            }.store(in: &bindings)
    }

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        let verticalStackLayout = ASStackLayoutSpec(
            direction: .vertical,
            spacing: 8,
            justifyContent: .start,
            alignItems: .start,
            children: [name, repositoryDescription]
        )
        if !(language.attributedText?.string.isEmpty ?? true) {
            verticalStackLayout.setChild(language, at: 1)
        }
        verticalStackLayout.style.flexShrink = 1
        verticalStackLayout.style.flexGrow = 1
        verticalStackLayout.style.flexBasis = ASDimensionMake("80%")
        stars.style.flexBasis = ASDimensionMake("20%")

        let horizontalStackLayout = ASStackLayoutSpec(
            direction: .horizontal,
            spacing: 16,
            justifyContent: .spaceAround,
            alignItems: .center,
            children: [verticalStackLayout, stars]
        )

        let headerInsetLayout = ASInsetLayoutSpec(insets: UIEdgeInsets(top: 8, left: 12, bottom: 0, right: 12), child: horizontalStackLayout)

        let imageStackLayout = ASStackLayoutSpec(
            direction: .vertical,
            spacing: 8,
            justifyContent: .start,
            alignItems: .start,
            children: [headerInsetLayout, image]
        )
        imageStackLayout.style.preferredLayoutSize = ASLayoutSize(width: .init(unit: .fraction, value: 1), height: .init(unit: .auto, value: 0))

        return imageStackLayout
    }

    func imageNode(_ imageNode: ASNetworkImageNode, didFailWithError error: Error) {
        print("image \(imageNode.url) loading error: \(error.localizedDescription)")
    }
}
