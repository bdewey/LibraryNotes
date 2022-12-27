// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import UIKit

extension UIBarButtonItem {
  static var toggleBoldface: UIBarButtonItem {
    UIBarButtonItem(title: "Bold", image: UIImage(systemName: "bold"), target: nil, action: #selector(UIResponderStandardEditActions.toggleBoldface))
  }

  static var toggleItalics: UIBarButtonItem {
    UIBarButtonItem(title: "Italic", image: UIImage(systemName: "italic"), target: nil, action: #selector(UIResponderStandardEditActions.toggleItalics))
  }
}
