//
//  AuthViewController.swift
//  GithubTexture
//
//  Created by Bogdan Redkin on 04.08.2022.
//

import AsyncDisplayKit
import Combine
import SafariServices
import UIKit

class AuthViewController: ASDKViewController<ASDisplayNode> {
    private enum Constants {
        static let authButtonWidth: CGFloat = 150
        static let activityIndicatorWidth: CGFloat = 50
    }

    private let errorTextNode = ASTextNode()
    private lazy var authButton: ASButtonNode = {
        let button = ASButtonNode()
        button.setTitle("Authorize", with: UIFont.systemFont(ofSize: UIFont.systemFontSize), with: .black, for: .normal)
        button.addTarget(self, action: #selector(authButtonTouchUpInside), forControlEvents: .touchUpInside)
        button.style.preferredSize = CGSize(width: Constants.authButtonWidth, height: UIFont.systemFontSize * 2)
        return button
    }()

    private lazy var activityIndicator: ASDisplayNode = {
        let activityIndicator = ASDisplayNode()
        activityIndicator.setViewBlock {
            let view = UIActivityIndicatorView()
            return view
        }
        activityIndicator.style.preferredSize = CGSize(width: Constants.activityIndicatorWidth, height: Constants.activityIndicatorWidth)
        return activityIndicator
    }()

    private var bindings = Set<AnyCancellable>()
    private let viewModel: AuthViewModel

    init(viewModel: AuthViewModel) {
        self.viewModel = viewModel
        super.init(node: ASDisplayNode())
        node.backgroundColor = .white
        node.automaticallyManagesSubnodes = true
        node.layoutSpecBlock = { [weak self] _, _ in
            guard let self = self else { return ASLayoutSpec() }
            let overlayLayout = ASOverlayLayoutSpec(child: self.authButton, overlay: self.activityIndicator)
            let stackLayout = ASStackLayoutSpec(
                direction: .vertical,
                spacing: 4,
                justifyContent: .center,
                alignItems: .center,
                children: [self.errorTextNode, overlayLayout]
            )
            let centerLayout = ASCenterLayoutSpec(centeringOptions: .XY, sizingOptions: .minimumXY, child: stackLayout)
            return centerLayout
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.$currentState.receive(on: RunLoop.main).sink { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .loading:
                (self.activityIndicator.view as? UIActivityIndicatorView)?.startAnimating()
                self.authButton.isHidden = true
                self.errorTextNode.isHidden = true
            case .unauthorized:
                (self.activityIndicator.view as? UIActivityIndicatorView)?.stopAnimating()
                self.authButton.isHidden = false
                self.errorTextNode.isHidden = true
            case let .error(message):
                self.errorTextNode.isHidden = false
                self.errorTextNode.attributedText = NSAttributedString(
                    string: message,
                    attributes: [.font: UIFont.boldSystemFont(ofSize: 17), .foregroundColor: UIColor.black]
                )
                self.authButton.isHidden = true
                (self.activityIndicator.view as? UIActivityIndicatorView)?.stopAnimating()
            case let .authorizing(authUrl):
                let safariVC = SFSafariViewController(url: authUrl)
                self.navigationController?.present(safariVC, animated: true, completion: nil)
            case .authorized:
                self.navigationController?.presentedViewController?.dismiss(animated: true, completion: nil)
                let searchViewController = GithubSearchAssembly.assembly()
                self.navigationController?.isNavigationBarHidden = false
                self.navigationController?.setViewControllers([searchViewController], animated: true)
            case .offline:
                self.errorTextNode.attributedText = NSAttributedString(
                    string: "Offline mode",
                    attributes: [.font: UIFont.boldSystemFont(ofSize: 17), .foregroundColor: UIColor.black]
                )
                self.authButton.isHidden = false
                (self.activityIndicator.view as? UIActivityIndicatorView)?.stopAnimating()
            }
        }.store(in: &bindings)
    }

    @objc private func authButtonTouchUpInside() {
        switch viewModel.currentState {
        case .offline:
            self.navigationController?.presentedViewController?.dismiss(animated: true, completion: nil)
            let searchViewController = GithubSearchAssembly.assembly(offline: true)
            self.navigationController?.isNavigationBarHidden = false
            self.navigationController?.setViewControllers([searchViewController], animated: true)
        default:
            viewModel.authButtonTapped()
        }
    }
}
