// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Logging
import UIKit
import WebKit

extension Logger {
  static let webViewLoggerLabel = "org.brians-brain.WebViewController"
  static let webView = Logger(label: webViewLoggerLabel)
}

public final class WebViewController: UIViewController, ReferenceViewController {
  public init(url: URL) {
    self.initialURL = url
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public var relatedNotesViewController: UIViewController?
  private var initialURL: URL

  private lazy var webView: WKWebView = {
    let preferences = WKPreferences()
    preferences.isFraudulentWebsiteWarningEnabled = true
    let configuration = WKWebViewConfiguration()
    configuration.preferences = preferences
    let view = WKWebView(frame: .zero, configuration: configuration)
    view.navigationDelegate = self
    view.load(URLRequest(url: initialURL))
    return view
  }()

  override public func loadView() {
    view = webView
  }

  override public func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    configureToolbar()
  }

  override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    configureToolbar()
  }

  @objc private func showNotes() {
    guard let relatedNotesViewController = relatedNotesViewController else { return }
    Logger.shared.info("Should show notes now")
    let navigationController = UINavigationController(rootViewController: relatedNotesViewController)
    navigationController.navigationBar.prefersLargeTitles = false
    navigationController.navigationBar.barTintColor = .grailBackground
    navigationController.navigationBar.tintColor = .systemOrange
    navigationController.hidesBarsOnSwipe = false
    navigationController.view.tintColor = .systemOrange
    present(navigationController, animated: true, completion: nil)
  }

  private func configureToolbar() {
    let showNotesButton = UIBarButtonItem(image: UIImage(systemName: "note.text"), style: .plain, target: self, action: #selector(showNotes))
    showNotesButton.accessibilityIdentifier = "show-notes"

    if splitViewController?.isCollapsed ?? false {
      navigationItem.rightBarButtonItems = []
      navigationController?.isToolbarHidden = false
      toolbarItems = [showNotesButton, UIBarButtonItem.flexibleSpace(), AppCommandsButtonItems.newNote()]
    } else {
      navigationItem.rightBarButtonItems = [AppCommandsButtonItems.newNote(), showNotesButton]
      navigationController?.isToolbarHidden = true
      toolbarItems = []
    }
  }
}

// MARK: - WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {}
