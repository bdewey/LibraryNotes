// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

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
            let message = messageComponents.compactMap { $0 }.joined(separator: "\n\n")
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
    sharedDefaults?.pendingSavedURLs.append(SavedURL(url: shareConfiguration.url, message: contentText))
    super.didSelectPost()
  }

  override func configurationItems() -> [Any]! {
    // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
    return []
  }
}
