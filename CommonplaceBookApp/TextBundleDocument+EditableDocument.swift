// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation
import textbundle_swift

extension TextBundleDocument: EditableDocument {
  
  var text: String {
    return (try? self.textBundle.text()) ?? ""
  }
  
  // TODO: Eww.
  func applyChange(_ change: StringChange) {
    do {
      let text = try self.textBundle.text()
      let inverse = text.inverse(of: change)
      undoManager.registerUndo(withTarget: self) { (doc) in
        do {
          let text = try doc.textBundle.text()
          try doc.textBundle.setText(text.applyingChange(inverse))
        } catch {
          // NOTHING
        }
      }
      try textBundle.setText(text.applyingChange(change))
    } catch {
      // NOTHING
    }
  }
}
