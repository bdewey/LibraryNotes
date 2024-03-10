// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import os
import UIKit
import WebKit

extension Logger {
  static var webView: Logger {
    Logger(subsystem: Bundle.main.bundleIdentifier!, category: "WebViewController")
  }
}

public final class WebViewController: UIViewController {
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

  public override func viewDidLoad() {
    super.viewDidLoad()
    registerForTraitChanges([UITraitHorizontalSizeClass.self], action: #selector(configureToolbar))
  }

  public override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    configureToolbar()
  }

  @objc private func showNotes() {
    guard let relatedNotesViewController else { return }
    Logger.shared.info("Should show notes now")
    let navigationController = UINavigationController(rootViewController: relatedNotesViewController)
    navigationController.navigationBar.prefersLargeTitles = false
    navigationController.navigationBar.barTintColor = .grailBackground
    navigationController.navigationBar.tintColor = .systemOrange
    navigationController.hidesBarsOnSwipe = false
    navigationController.view.tintColor = .systemOrange
    present(navigationController, animated: true, completion: nil)
  }

  @objc
  private func configureToolbar() {
    let showNotesButton = UIBarButtonItem(image: UIImage(systemName: "note.text"), style: .plain, target: self, action: #selector(showNotes))
    showNotesButton.accessibilityIdentifier = "show-notes"

    if splitViewController?.isCollapsed ?? false {
      navigationItem.rightBarButtonItems = []
      navigationController?.isToolbarHidden = false
      toolbarItems = [showNotesButton, UIBarButtonItem.flexibleSpace(), NotebookViewController.makeNewNoteButtonItem()].compactMap { $0 }
    } else {
      navigationItem.rightBarButtonItems = [NotebookViewController.makeNewNoteButtonItem(), showNotesButton].compactMap { $0 }
      navigationController?.isToolbarHidden = true
      toolbarItems = []
    }
  }
}

// MARK: - WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {}
