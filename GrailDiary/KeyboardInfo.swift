// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import UIKit

public struct KeyboardInfo {
  public var animationCurve: UIView.AnimationCurve
  public var animationDuration: Double
  public var isLocal: Bool
  public var frameBegin: CGRect
  public var frameEnd: CGRect
}

extension KeyboardInfo {
  init?(_ notification: Notification) {
    guard notification.name == UIResponder.keyboardWillShowNotification ||
      notification.name == UIResponder.keyboardWillChangeFrameNotification
    else {
      return nil
    }
    let userInfo = notification.userInfo!

    // swiftlint:disable force_cast
    self.animationCurve = UIView.AnimationCurve(
      rawValue: userInfo[UIWindow.keyboardAnimationCurveUserInfoKey] as! Int
    )!
    self.animationDuration = userInfo[UIWindow.keyboardAnimationDurationUserInfoKey] as! Double
    self.isLocal = userInfo[UIWindow.keyboardIsLocalUserInfoKey] as! Bool
    self.frameBegin = userInfo[UIWindow.keyboardFrameBeginUserInfoKey] as! CGRect
    self.frameEnd = userInfo[UIWindow.keyboardFrameEndUserInfoKey] as! CGRect
    // swiftlint:enable force_cast
  }
}
