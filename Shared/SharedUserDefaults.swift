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
