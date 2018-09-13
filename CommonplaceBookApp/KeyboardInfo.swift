// Copyright © 2018 Brian's Brain. All rights reserved.

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
      notification.name == UIResponder.keyboardWillChangeFrameNotification else {
        return nil
    }
    let userInfo = notification.userInfo!

    // swiftlint:disable force_cast
    animationCurve = UIView.AnimationCurve(
      rawValue: userInfo[UIWindow.keyboardAnimationCurveUserInfoKey] as! Int
      )!
    animationDuration = userInfo[UIWindow.keyboardAnimationDurationUserInfoKey] as! Double
    isLocal = userInfo[UIWindow.keyboardIsLocalUserInfoKey] as! Bool
    frameBegin = userInfo[UIWindow.keyboardFrameBeginUserInfoKey] as! CGRect
    frameEnd = userInfo[UIWindow.keyboardFrameEndUserInfoKey] as! CGRect
    // swiftlint:enable force_cast
  }
}
