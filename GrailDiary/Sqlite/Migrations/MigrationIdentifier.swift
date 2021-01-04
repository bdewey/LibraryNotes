// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

/// This is just a "namespace" enum for extending with specific migrations.
internal enum MigrationIdentifier: String {
  case initialSchema
  case deviceUUIDKey = "20201213-deviceUUIDKey"
  case noFlakeNote = "20201214-noFlakeNote"
  case noFlakeChallengeTemplate = "20201214-noFlakeChallengeTemplate"
  case addContentTable = "20201219-content"
  case changeContentKey = "20201220-contentKey"
  case prompts = "20201221-prompt"
  case promptTable = "20201223-promptTable"
  case links = "20201223-links"
  case binaryContent = "20201227-binaryContent"
  case creationTimestamp = "20210103-creationTimestamp"
}
