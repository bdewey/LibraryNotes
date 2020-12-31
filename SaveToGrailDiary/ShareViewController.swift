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

final class ShareViewController: SLComposeServiceViewController {
  private let sharedDefaults = UserDefaults(suiteName: appGroupName)

  override func viewDidLoad() {
    super.viewDidLoad()
  }

  func loadURL(completion: @escaping (Result<NSURL, Error>) -> Void) {
    let inputItems = (extensionContext?.inputItems ?? []).compactMap { $0 as? NSExtensionItem }
    for item in inputItems {
      for attachment in item.attachments ?? [] where attachment.canLoadObject(ofClass: NSURL.self) {
        attachment.loadObject(ofClass: NSURL.self) { url, error in
          if let url = url as? NSURL {
            completion(.success(url))
          } else if let error = error {
            completion(.failure(error))
          } else {
            preconditionFailure()
          }
        }
      }
    }
  }

  override func isContentValid() -> Bool {
    // Do validation of contentText and/or NSExtensionContext attachments here
    return true
  }

  override func didSelectPost() {
    // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
    loadURL { [weak self] result in
      guard let self = self else { return }
      switch result {
      case .success(let url):
        self.sharedDefaults?.pendingSavedURLs.append(SavedURL(url: url as URL, message: self.contentText ?? ""))
      case .failure:
        let alert = UIAlertController(title: "Error", message: "Unexpected error", preferredStyle: .alert)
        self.present(alert, animated: true, completion: nil)
      }
      // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
      self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }
  }

  override func configurationItems() -> [Any]! {
    // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
    return []
  }
}
