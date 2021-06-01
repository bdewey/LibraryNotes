// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Logging
import UIKit

/// A view that contains a scroll view and a header placed on top of that scroll view. As you scroll down the scroll view, the container will adjust the offset of the header
/// so it appears to scroll offscreen with its content.  When you scroll up, it will bring the header back no matter how far down you've scrolled.
///
/// - note: `ScrollawayContainerView` does not make itself a delegate of its scroll view. You are responsible for becoming a delegate and calling `scrollViewDidScroll`
/// to provide the scrollaway effect.
final class ScrollawayContainerView: UIView {
  /// The scroll view that we manage. It will fill the bounds of the container.
  var scrollView: UIScrollView? {
    willSet {
      scrollView?.removeFromSuperview()
    }
    didSet {
      scrollView.flatMap(addSubview)
      scrollawayHeaderView.flatMap(bringSubviewToFront)
      setNeedsLayout()
    }
  }

  /// An optional view that will appear at the top of the textView and scroll away as the content scrolls.
  /// This view will be stretched to fit the width of the container and it will be placed "somewhere near the top" depending on scroll state.
  /// The container will call `sizeThatFits` on this view to determine the appropriate container height.
  var scrollawayHeaderView: UIView? {
    willSet {
      scrollawayHeaderView?.removeFromSuperview()
    }
    didSet {
      scrollawayHeaderView.flatMap(addSubview)
      scrollawayHeaderView.flatMap(bringSubviewToFront)
      sizeScrollawayHeaderViewToFit()
      setNeedsLayout()
      scrollawayContentAnchor = scrollView?.contentOffset.y ?? 0
    }
  }

  /// To create the illusion of scrolling with its content, the top of `scrollawayHeaderView` will be positioned on top of this y-offset in the content.
  private var scrollawayContentAnchor: CGFloat = 0

  /// You must call this when `scrollView` scrolls in order to provide the scrollaway effect.
  func scrollViewDidScroll() {
    layoutScrollawayHeaderView()
  }

  func showScrollawayHeader() {
    forceScrollawayViewToTop = true
    setNeedsLayout()
  }

  override func layoutSubviews() {
    scrollView?.frame = bounds
    layoutScrollawayHeaderView()
  }

  override var bounds: CGRect {
    get { super.bounds }
    set {
      super.bounds = newValue
      sizeScrollawayHeaderViewToFit()
      setNeedsLayout()
    }
  }

  private func sizeScrollawayHeaderViewToFit() {
    let readableContentGuide = readableContentGuide
    if let scrollawayHeaderView = scrollawayHeaderView {
      scrollawayHeaderView.layoutMargins = UIEdgeInsets(
        top: 8,
        left: readableContentGuide.layoutFrame.minX,
        bottom: 8,
        right: bounds.maxX - readableContentGuide.layoutFrame.maxX
      )
      let scrollawayHeight = scrollawayHeaderView.sizeThatFits(CGSize(width: bounds.width, height: .greatestFiniteMagnitude)).height
      scrollawayHeaderView.frame.size = CGSize(
        width: bounds.width,
        height: scrollawayHeight
      )
      Logger.scrollaway.info("Computed header size: \(scrollawayHeaderView.frame.size)")
    }
  }

  private var forceScrollawayViewToTop = false

  private func layoutScrollawayHeaderView() {
    guard let scrollawayHeaderView = scrollawayHeaderView, let scrollView = scrollView else {
      return
    }
    if forceScrollawayViewToTop {
      forceScrollawayViewToTop = false
      scrollawayContentAnchor = scrollView.contentOffset.y
      Logger.scrollaway.debug("forceScrollawayViewToTop is true. scrollawayContentAnchor = \(scrollawayContentAnchor)")
    }
    let maxScrollAmount = scrollawayHeaderView.frame.size.height
    var newTopConstraintConstant = scrollawayContentAnchor - scrollView.contentOffset.y
    if newTopConstraintConstant < -maxScrollAmount {
      scrollawayContentAnchor = scrollView.contentOffset.y - maxScrollAmount
      newTopConstraintConstant = -maxScrollAmount
    } else if newTopConstraintConstant > 0 {
      scrollawayContentAnchor = max(scrollView.contentOffset.y, -scrollView.adjustedContentInset.top)
      newTopConstraintConstant = scrollawayContentAnchor - scrollView.contentOffset.y
    }
    scrollawayHeaderView.frame = CGRect(
      origin: CGPoint(x: 0, y: safeAreaInsets.top + newTopConstraintConstant),
      size: CGSize(width: bounds.width, height: scrollawayHeaderView.bounds.height)
    )
    Logger.scrollaway.debug("New scrollaway frame = \(scrollawayHeaderView.frame). scrollawayContentAnchor = \(scrollawayContentAnchor). contentOffset.y = \(scrollView.contentOffset.y)")
  }
}

private extension Logger {
  static let scrollaway: Logger = {
    var logger = Logger(label: "org.brians-brain.ScrollawayContainerView")
    logger.logLevel = .info
    return logger
  }()
}
