// Copyright (c) 2018-2025  Brian Dewey. Covered by the Apache 2.0 license.

import LibraryNotesCore
import UIKit

extension UIViewController {
  /// A conveniene method for wrapping a view controller in a UINavigationController with fluent syntax.
  func wrappingInNavigationController() -> UINavigationController {
    let navigationController = UINavigationController(rootViewController: self)
    navigationController.navigationBar.barTintColor = .grailBackground
    return navigationController
  }
}
