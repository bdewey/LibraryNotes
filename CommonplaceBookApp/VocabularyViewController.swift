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

  private let notebook: NoteArchiveDocument

  // MARK: - Lifecycle

  override func viewDidLoad() {
    view.backgroundColor = UIColor.systemBackground
  }
}
