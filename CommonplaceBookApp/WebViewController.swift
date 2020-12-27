//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

import Logging
import UIKit
import WebKit

extension Logger {
  static let webViewLoggerLabel = "org.brians-brain.WebViewController"
  static let webView = Logger(label: webViewLoggerLabel)
}

public final class WebViewController: UIViewController {

  public init(url: URL) {
    self.initialURL = url
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

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

  public override func loadView() {
    self.view = webView
  }

  public override func viewDidLoad() {
    super.viewDidLoad()

    // Do any additional setup after loading the view.
  }
}

// MARK: - WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {
}
