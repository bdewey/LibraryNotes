// Copyright © 2018 Brian's Brain. All rights reserved.

import UIKit

import CommonplaceBook
import MaterialComponents

/// Allows editing of a single text file.
final class TextEditViewController: UIViewController, UITextViewDelegate {
  
  let commonplaceBook: CommonplaceBook
  let documentURL: URL
  
  let appBar: MDCAppBar = {
    let appBar = MDCAppBar()
    MDCAppBarColorThemer.applySemanticColorScheme(Stylesheet.default.colorScheme, to: appBar)
    MDCAppBarTypographyThemer.applyTypographyScheme(Stylesheet.default.typographyScheme, to: appBar)
    return appBar
  }()
  
  let textView: UITextView = {
    let textView = UITextView(frame: .zero)
    textView.backgroundColor = .white
    textView.font = Stylesheet.default.typographyScheme.body2
    return textView
  }()
  
  /// Designated initializer.
  init(commonplaceBook: CommonplaceBook, documentURL: URL) {
    self.commonplaceBook = commonplaceBook
    self.documentURL = documentURL
    super.init(nibName: nil, bundle: nil)
    self.navigationItem.title = "Commonplace Book"
    self.addChild(appBar.headerViewController)
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Lifecycle
  override func loadView() {
    self.view = textView
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    appBar.addSubviewsToParent()
    appBar.headerViewController.headerView.trackingScrollView = textView
    textView.delegate = self
    
    commonplaceBook.openDocument(
      at: documentURL.lastPathComponent,
      using: PlainTextDocument.Factory.default
    ) { (result) in
      switch result {
      case .success(let document):
        self.textView.text = document.text
      case .failure(let error):
        let messageText = "Error opening \(self.documentURL): \(error.localizedDescription)"
        let message = MDCSnackbarMessage(text: messageText)
        MDCSnackbarManager.show(message)
        print(messageText)
      }
    }
  }
  
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    appBar.headerViewController.headerView.trackingScrollDidScroll()
  }
  
  func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    appBar.headerViewController.headerView.trackingScrollDidEndDecelerating()
  }
  
  func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    appBar.headerViewController.headerView.trackingScrollDidEndDraggingWillDecelerate(decelerate)
  }
  
  func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    appBar.headerViewController.headerView.trackingScrollWillEndDragging(withVelocity: velocity, targetContentOffset: targetContentOffset)
  }
}
