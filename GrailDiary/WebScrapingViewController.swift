// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Logging
import UIKit
import WebKit

public protocol WebScrapingViewControllerDelegate: AnyObject {
  func webScrapingViewController(_ viewController: WebScrapingViewController, didScrapeMarkdown: String)
  func webScrapingViewControllerDidCancel(_ viewController: WebScrapingViewController)
}

public final class WebScrapingViewController: UIViewController {
  init(initialURL: URL) {
    self.initialURL = initialURL
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public weak var delegate: WebScrapingViewControllerDelegate?
  public let initialURL: URL

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

  private lazy var goBackButton = UIBarButtonItem(
    image: UIImage(systemName: "chevron.backward"),
    primaryAction: UIAction { [weak self] _ in
      self?.webView.goBack()
    }
  )

  private lazy var goForwardButton = UIBarButtonItem(
    image: UIImage(systemName: "chevron.forward"),
    primaryAction: UIAction { [weak self] _ in
      self?.webView.goForward()
    }
  )

  private lazy var importButton = UIBarButtonItem(
    image: UIImage(systemName: "square.and.arrow.down"),
    primaryAction: UIAction { [weak self] _ in
      self?.runImportScript()
    }
  )

  public override func loadView() {
    self.view = webView
  }

  override public func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
      guard let self = self else { return }
      self.delegate?.webScrapingViewControllerDidCancel(self)
    })
    navigationItem.rightBarButtonItem = importButton
    toolbarItems = [
      UIBarButtonItem.flexibleSpace(),
      goBackButton,
      UIBarButtonItem.flexibleSpace(),
      goForwardButton,
      UIBarButtonItem.flexibleSpace(),
    ]
    navigationController?.setToolbarHidden(false, animated: false)
    configureUI()
  }
}

// MARK: - Private

private extension WebScrapingViewController {
  func configureUI() {
    goBackButton.isEnabled = webView.canGoBack
    goForwardButton.isEnabled = webView.canGoForward
    title = webView.url?.host
  }

  func runImportScript() {
    webView.evaluateJavaScript(javascript) { [weak self] result, error in
      guard let self = self else { return }
      if let result = result as? String {
        self.delegate?.webScrapingViewController(self, didScrapeMarkdown: result)
      } else {
        Logger.shared.error("Unexpected error running Javascript: \(String(describing: error))")
      }
    }
  }
}

// MARK: - WKNavigationDelegate

extension WebScrapingViewController: WKNavigationDelegate {
  public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    configureUI()
  }
}

private let javascript = #"""
  "use strict";
  var _a, _b;
  const title = (_a = window.document.querySelector("h3.kp-notebook-metadata")) === null || _a === void 0 ? void 0 : _a.textContent;
  const author = (_b = window.document.querySelector("p.kp-notebook-metadata.a-color-secondary")) === null || _b === void 0 ? void 0 : _b.textContent;
  const elements = Array.from(window.document.getElementsByClassName("kp-notebook-highlight"));
  const quotes = elements.map(e => `> ${e.textContent}`).join("\n\n");
  `# ${title}: ${author}\n\n${quotes}`;
"""#
