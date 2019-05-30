// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation

internal final class ResourceBundle {
  internal static let bundle: Bundle = {
    let bundle = Bundle(for: VocabularyViewController.self)
    let resourceBundleURL = bundle.url(forResource: "FlashcardKit", withExtension: "bundle")
    return Bundle(url: resourceBundleURL!)!
  }()
}
