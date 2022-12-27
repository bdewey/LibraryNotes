// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import UIKit

/// Provides rich text editing of a single file.
public final class RichTextEditViewController: UIViewController {
  /// Designated initializer.
  public init(imageStorage: NoteScopedImageStorage) {
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
