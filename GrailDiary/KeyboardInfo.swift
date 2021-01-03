//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

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
