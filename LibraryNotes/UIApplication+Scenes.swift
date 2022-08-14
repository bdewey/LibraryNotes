//  Copyright © 2022 Brian's Brain. All rights reserved.

import UIKit

extension UIApplication {
  func firstConnectedWindowScene(where predicate: (UIWindowScene) -> Bool) -> UIWindowScene? {
    for scene in connectedScenes {
      guard let windowScene = scene as? UIWindowScene else {
        continue
      }
      if predicate(windowScene) {
        return windowScene
      }
    }
    return nil
  }

  func firstConnectedWindowSceneWithRootViewController<ViewController: UIViewController>(
    type: ViewController.Type,
    predicate: (ViewController) -> Bool
  ) -> UIWindowScene? {
    firstConnectedWindowScene { windowScene in
      guard let rootViewController = windowScene.keyWindow?.rootViewController as? ViewController else {
        return false
      }
      return predicate(rootViewController)
    }
  }
}
