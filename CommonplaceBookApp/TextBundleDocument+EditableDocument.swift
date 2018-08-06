// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation
import textbundle_swift

extension TextBundleDocument: EditableDocument {
  
  public var text: String {
    return (try? self.textBundle.text()) ?? ""
  }
  
  // TODO: Eww.
  public func applyChange(_ change: StringChange) {
    do {
      var text = try self.textBundle.text()
      let inverse = text.applyChange(change)
      undoManager.registerUndo(withTarget: self) { (doc) in
        do {
          var text = try doc.textBundle.text()
          text.applyChange(inverse)
          try doc.textBundle.setText(text)
        } catch {
          // NOTHING
        }
      }
      try textBundle.setText(text)
    } catch {
      // NOTHING
    }
  }
}
