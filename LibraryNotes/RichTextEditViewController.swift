// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import SnapKit
import UIKit
import UniformTypeIdentifiers

/// Provides rich text editing of a single file.
public final class RichTextEditViewController: UIViewController, TextEditViewController {
  /// Designated initializer.
  public init(imageStorage: NoteScopedImageStorage) {
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private lazy var textView = UITextView(frame: .zero)

  // MARK: - View lifecycle

  override public func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(textView)
    textView.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
  }

  public var markdown: String {
    get {
      textView.text
    }
    set {
      textView.text = newValue
    }
  }

  public var navigationTitleView: UIView?

  public var extendedNavigationHeaderView: UIView?

  public var autoFirstResponder: Bool = false

  public weak var delegate: TextEditViewControllerDelegate?

  public func editEndOfDocument() {
    #warning("Not implemented")
    fatalError()
  }

  public var selectedRange: NSRange {
    get {
      textView.selectedRange
    }
    set {
      textView.selectedRange = newValue
    }
  }

  public var selectedRawTextRange: NSRange {
    get {
      textView.selectedRange
    }
    set {
      textView.selectedRange = newValue
    }
  }

  public func insertImageData(_ imageData: Data, type: UTType) throws {
    #warning("Not implemented")
    fatalError()
  }
}
