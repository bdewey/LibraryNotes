// Copyright © 2019 Brian's Brain. All rights reserved.

import Foundation

/// Generic protocol for things that can be observed.
/// - note: Observers should be weakly held, and it is not strictly required to call
///         `removeObserver`. If the observer goes away, everything continues to work.
public protocol Observable {
  associatedtype Observer

  /// Adds an observer.
  func addObserver(_ observer: Observer)

  /// Removes an observer.
  /// - note: Calling this is an optimization. Observers are weakly held by the observable
  /// and everything still works if the observer is deallocated.
  func removeObserver(_ observer: Observer)
}
