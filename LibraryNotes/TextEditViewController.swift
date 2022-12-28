// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import Foundation
import UIKit
import UniformTypeIdentifiers

public protocol TextEditViewControllerDelegate: AnyObject {
  func textEditViewControllerDidChangeContents(_ viewController: TextEditViewController)
  func textEditViewControllerDidClose(_ viewController: TextEditViewController)
  func testEditViewController(_ viewController: TextEditViewController, hashtagSuggestionsFor hashtag: String) -> [String]
  func textEditViewController(_ viewController: TextEditViewController, didAttach book: AugmentedBook)
}

/// A UIViewController that allows editing of a single text file.
public protocol TextEditViewController: UIViewController {
  var markdown: String { get set }
  var navigationTitleView: UIView? { get set }
  var extendedNavigationHeaderView: UIView? { get set }
  func editEndOfDocument()
  var selectedRange: NSRange { get set }
  var selectedRawTextRange: NSRange { get set }
  func insertImageData(_ imageData: Data, type: UTType) throws
  var autoFirstResponder: Bool { get set }
  var delegate: TextEditViewControllerDelegate? { get set }
}

@objc protocol TextEditingFormattingActions {
  /// Turns the current paragraph into a summary (`tl;dr:`) paragraph if it isn't, or a normal paragraph if it is.
  func toggleSummaryParagraph()

  /// Turns the current paragraph into a first-level heading (`# `) if it isn't, or a normal paragraph if it is.
  func toggleHeading()

  /// Turns the current paragraph into a second-level heading (`## `) if it isn't, or a normal paragraph if it is.
  func toggleSubheading()

  /// Turns the current paragraph into a quote (`> `) if it isn't one, or a normal paragraph if it is.
  func toggleQuote()

  /// Turns the current paragraph into a bullet list item (`* `) if it isn't one, or a normal paragraph if it is.
  func toggleBulletList()

  /// Turns the current paragraph into a numbed list item (`1. `) if it isn't one, or a normal paragraph if it is.
  func toggleNumberedList()
}
