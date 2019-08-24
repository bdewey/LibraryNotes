// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation

/// A simple propertyWrapper for persisting values in UserDefaults.standard
@propertyWrapper
struct UserDefault<T> {
  /// The key for persisting the value in UserDefaults.standard
  let key: String
  /// The default value
  let defaultValue: T?

  init(_ key: String, defaultValue: T?) {
    self.key = key
    self.defaultValue = defaultValue
  }

  var wrappedValue: T? {
    get {
      return UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
    }
    set {
      UserDefaults.standard.set(newValue, forKey: key)
    }
  }
}
