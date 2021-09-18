// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import UIKit

extension UIResponder {
  func printResponderChain() {
    var responder: UIResponder? = self
    while let currentResponder = responder {
      print(currentResponder)
      responder = currentResponder.next
    }
  }

  func responderChain() -> String {
    var responderStrings = [String]()
    var responder: UIResponder? = self
    while let currentResponder = responder {
      responderStrings.append(String(describing: currentResponder))
      responder = currentResponder.next
    }
    return responderStrings.joined(separator: "\n")
  }
}
