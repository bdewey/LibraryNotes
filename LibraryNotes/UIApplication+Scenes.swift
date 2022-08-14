//  Copyright © 2022 Brian's Brain. All rights reserved.

import UIKit

extension UIApplication {
  /// Returns the first connected window scene that matches a predicate.
  /// - Parameter predicate: The predicate condition for the window scene.
  /// - Returns: The first windowScene where `predicate` returns true, or `nil` if no window scenes match the predicate.
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

  /// Returns the first window scene that has a root view controller that matches a predicate.
  /// - Parameters:
  ///   - type: The type of root view controller to look for.
  ///   - predicate: A closure that takes a `ViewController` as its argument and returns a Boolean indicating if the view controller is a match.
  /// - Returns: The matching view controller, if found; otherwise nil.
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

  /// Activates or creates a study session scene.
  ///
  /// If there is currently a study session scene for this database, that scene will be activated without modification. Otherwise, this function will request the creation of a new
  /// scene to study the specified target.
  /// - Parameters:
  ///   - databaseURL: The database URL we are studying.
  ///   - studyTarget: The content to study.
  func activateStudySessionScene(databaseURL: URL, studyTarget: NSUserActivity.StudyTarget) {
    let options = UIScene.ActivationRequestOptions()
    options.collectionJoinBehavior = .disallowed
    if let existingScene = firstConnectedWindowSceneWithRootViewController(type: StudyViewController.self, predicate: { studyViewController in
      studyViewController.database.fileURL == databaseURL
    }) {
      requestSceneSessionActivation(existingScene.session, userActivity: nil, options: options)
    } else if let activity = try? NSUserActivity.studySession(databaseURL: databaseURL, studyTarget: studyTarget) {
      UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: options)
    }
  }
}
