// Copyright © 2017-present Brian's Brain. All rights reserved.

import UIKit

/// Allows editing a vocabulary list.
final class VocabularyViewController: UIViewController {
  init(notebook: NoteArchiveDocument) {
    self.notebook = notebook
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// The notebook we write changes back to
  let notebook: NoteArchiveDocument

  /// The page that stores our vocabulary.
  var properties = PageProperties() {
    didSet {
      title = properties.title
    }
  }

  /// Identifier of the page. If nil, it means we're working with unsaved content.
  var pageIdentifier: String?

  // MARK: - Lifecycle

  override func viewDidLoad() {
    view.backgroundColor = UIColor.systemBackground
  }
}
