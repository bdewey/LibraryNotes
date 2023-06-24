//
//  LibraryNotesTextView.swift
//  LibraryNotes
//
//  Created by Brian Dewey on 1/16/23.
//  Copyright © 2023 Brian's Brain. All rights reserved.
//

import Logging
import UIKit

private extension Logger {
  static let textView: Logger = {
    var logger = Logger(label: "org.brians-brain.TextView")
    logger.logLevel = .trace
    return logger
  }()
}

final class LibraryNotesTextView: UITextView {
  override func caretRect(for position: UITextPosition) -> CGRect {
    var result = super.caretRect(for: position)
    if let font = super.textStyling(at: position, in: .forward)?[.font] as? UIFont {
      let caretHeight = font.lineHeight - font.descender
      Logger.textView.trace("\(#function) \(result) \(caretHeight)")
      result.size.height = caretHeight
    } else {
      return result
    }
    return result
  }

  override func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
    Logger.textView.trace("\(#function) Evaluating at \(offset)")
    var offset = offset
    while true {
      let result = super.position(from: position, offset: offset)
      if let result, textStyling(at: result, in: .forward).isUnselectable {
        Logger.textView.trace("\(#function) Skipping offset \(offset) because the position is unselectable")
        offset = offset.incrementMagnitude()
      } else {
        Logger.textView.trace("\(#function) Returning position at offset \(offset)")
        return result
      }
    }
  }

  override func position(from position: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
    let result = super.position(from: position, in: direction, offset: offset)
    Logger.textView.trace("\(#function) Offset \(offset) Direction \(direction.lnDescription) \(result?.description ?? "nil")")
    return result
  }
}

private extension Optional<[NSAttributedString.Key: Any]> {
  var isUnselectable: Bool {
    switch self {
    case .none:
      return false
    case .some(let wrapped):
      return wrapped[.isUnselectable] as? Bool ?? false
    }
  }
}

private extension UITextLayoutDirection {
  var lnDescription: String {
    switch self {
    case .right:
      return "right"
    case .left:
      return "left"
    case .up:
      return "up"
    case .down:
      return "down"
    }
  }
}

private extension Int {
  func incrementMagnitude() -> Int {
    if self < 0 {
      return self - 1
    } else {
      return self + 1
    }
  }
}
