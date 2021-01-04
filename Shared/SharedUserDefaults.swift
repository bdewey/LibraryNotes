// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

/// The shared app group used for communication between share extensions and the main app.
public let appGroupName = "group.org.brians-brain.grail-diary"

/// Serialization structure for saved URLs.
public struct SavedURL: Codable {
  let url: URL
  let message: String
}

public extension UserDefaults {
  private static let savedURLKey = "savedURLs"

  /// URLs that are pending to save into a note database.
  var pendingSavedURLs: [SavedURL] {
    get {
      if let data = self.data(forKey: Self.savedURLKey) {
        let items = try? JSONDecoder().decode([SavedURL].self, from: data)
        return items ?? []
      } else {
        return []
      }
    }
    set {
      if let encodedData = try? JSONEncoder().encode(newValue) {
        set(encodedData, forKey: Self.savedURLKey)
      }
    }
  }
}
