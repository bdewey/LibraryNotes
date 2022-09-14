// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

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
      if let rootViewController = windowScene.keyWindow?.rootViewController as? ViewController {
        return predicate(rootViewController)
      }
      if
        let navigationController = windowScene.keyWindow?.rootViewController as? UINavigationController,
        !navigationController.viewControllers.isEmpty,
        let rootViewController = navigationController.viewControllers[0] as? ViewController
      {
        return predicate(rootViewController)
      }
      return false
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
    #if targetEnvironment(macCatalyst)
      options.collectionJoinBehavior = .disallowed
    #endif
    if let existingScene = firstConnectedWindowSceneWithRootViewController(type: StudyViewController.self, predicate: { studyViewController in
      studyViewController.database.fileURL == databaseURL
    }) {
      requestSceneSessionActivation(existingScene.session, userActivity: nil, options: options)
    } else if let activity = try? NSUserActivity.studySession(databaseURL: databaseURL, studyTarget: studyTarget) {
      UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: options)
    }
  }

  /// Activates or creates a Random Quotes scene.
  ///
  /// If there is currently a Random Quotes scene for this database, that scene will be activated without modification.
  /// - Parameters:
  ///   - databaseURL: The database URL to extract random quotes from.
  ///   - quoteIdentifiers: The eligible quote identifiers.
  func activateRandomQuotesScene(databaseURL: URL, quoteIdentifiers: [ContentIdentifier]) {
    let options = UIScene.ActivationRequestOptions()
    #if targetEnvironment(macCatalyst)
      options.collectionJoinBehavior = .disallowed
    #endif
    if let existingScene = firstConnectedWindowSceneWithRootViewController(type: QuotesViewController.self, predicate: { quotesViewController in
      quotesViewController.database.fileURL == databaseURL
    }) {
      requestSceneSessionActivation(existingScene.session, userActivity: nil, options: options)
    } else if let activity = try? NSUserActivity.showRandomQuotes(databaseURL: databaseURL, quoteIdentifiers: quoteIdentifiers) {
      UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: options)
    }
  }
}
