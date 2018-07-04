// Copyright © 2018 Brian's Brain. All rights reserved.

import UIKit

import MaterialComponents

/// Allows editing of a single text file.
final class TextEditViewController: UIViewController, UITextViewDelegate {
  
  let appBar = MDCAppBar()
  let textView: UITextView = {
    let textView = UITextView(frame: .zero)
    textView.backgroundColor = .white
    return textView
  }()
  
  /// Designated initializer.
  init() {
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
    
    DispatchQueue.global(qos: .default).async {
      let text = try! String(contentsOf: Bundle.main.url(forResource: "remember", withExtension: "txt")!)
      DispatchQueue.main.async {
        self.textView.text = text
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
