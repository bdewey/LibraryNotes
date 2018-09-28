// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation

import MaterialComponents.MaterialAppBar

public protocol MDCScrollEventForwarder {
  var headerView: MDCFlexibleHeaderView? { get set }
  var desiredShiftBehavior: MDCFlexibleHeaderShiftBehavior { get }

  func forwardScrollViewDidScroll(_ scrollView: UIScrollView)
  func forwardScrollViewDidEndDecelerating(_ scrollView: UIScrollView)
  func forwardScrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool)
  func forwardScrollViewWillEndDragging(
    _ scrollView: UIScrollView,
    withVelocity velocity: CGPoint,
    targetContentOffset: UnsafeMutablePointer<CGPoint>
  )
}

public extension MDCScrollEventForwarder {
  func forwardScrollViewDidScroll(_ scrollView: UIScrollView) {
    if scrollView == headerView?.trackingScrollView {
      headerView?.trackingScrollDidScroll()
    }
  }

  func forwardScrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    if scrollView == headerView?.trackingScrollView {
      headerView?.trackingScrollDidEndDecelerating()
    }
  }

  func forwardScrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    if scrollView == headerView?.trackingScrollView {
      headerView?.trackingScrollDidEndDraggingWillDecelerate(decelerate)
    }
  }

  func forwardScrollViewWillEndDragging(
    _ scrollView: UIScrollView,
    withVelocity velocity: CGPoint,
    targetContentOffset: UnsafeMutablePointer<CGPoint>
  ) {
    if scrollView == headerView?.trackingScrollView {
      headerView?.trackingScrollWillEndDragging(
        withVelocity: velocity,
        targetContentOffset: targetContentOffset
      )
    }
  }
}
