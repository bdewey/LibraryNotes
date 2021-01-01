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

import Combine
import Logging
import Social
import UIKit
import UniformTypeIdentifiers

private struct ShareConfiguration {
  var url: URL
  var message: String
}

final class ShareViewController: SLComposeServiceViewController {
  private let sharedDefaults = UserDefaults(suiteName: appGroupName)

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Save to Grail Diary"
    loadShareConfiguration { [weak self] result in
      guard case .success(let shareConfiguration) = result else { return }
      self?.shareConfiguration = shareConfiguration
    }
  }

  private func loadShareConfiguration(completion: @escaping (Result<ShareConfiguration, Error>) -> Void) {
    let inputItems = (extensionContext?.inputItems ?? []).compactMap { $0 as? NSExtensionItem }
    for item in inputItems {
      for attachment in item.attachments ?? [] where attachment.canLoadObject(ofClass: NSURL.self) {
        attachment.loadObject(ofClass: NSURL.self) { url, error in
          if let url = url as? NSURL {
            let messageComponents: [String?] = [item.attributedTitle?.string, item.attributedContentText?.string, "#link"]
            let message = messageComponents.compactMap({ $0 }).joined(separator: "\n\n")
            let config = ShareConfiguration(url: url as URL, message: message)
            completion(.success(config))
          } else if let error = error {
            completion(.failure(error))
          } else {
            preconditionFailure()
          }
        }
      }
    }
  }

  private var shareConfiguration: ShareConfiguration? {
    didSet {
      validateContent()
      textView.text = shareConfiguration?.message
    }
  }

  override func isContentValid() -> Bool {
    return shareConfiguration != nil
  }

  override func didSelectPost() {
    guard let shareConfiguration = shareConfiguration else { return }
    self.sharedDefaults?.pendingSavedURLs.append(SavedURL(url: shareConfiguration.url, message: self.contentText))
    super.didSelectPost()
  }

  override func configurationItems() -> [Any]! {
    // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
    return []
  }
}
