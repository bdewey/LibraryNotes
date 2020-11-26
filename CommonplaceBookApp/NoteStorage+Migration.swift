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

public extension NoteDatabase {
  /// Copies the contents of the receiver to another storage.
  func migrate(to destination: NoteDatabase) throws {
    let metadata = allMetadata
    for identifier in metadata.keys {
      let note = try self.note(noteIdentifier: identifier)
      var oldToNewTemplateIdentifier = [FlakeID: FlakeID]()
      for template in note.challengeTemplates {
        let newIdentifier = destination.makeIdentifier()
        oldToNewTemplateIdentifier[template.templateIdentifier!] = newIdentifier
        template.templateIdentifier = newIdentifier
      }
      // TODO: This gives notes new UUIDs in the destination. Is that OK?
      _ = try destination.createNote(note)
      for entry in studyLog.filter({ oldToNewTemplateIdentifier.keys.contains($0.identifier.challengeTemplateID!) }) {
        var entry = entry
        entry.identifier.challengeTemplateID = oldToNewTemplateIdentifier[entry.identifier.challengeTemplateID!]
        try destination.recordStudyEntry(entry, buryRelatedChallenges: false)
      }
    }

    for assetKey in assetKeys {
      if let data = try self.data(for: assetKey) {
        // TODO: We don't get to set the key for the asset? That will break image rendering.
        // TODO: Oh no, how do I get the type hint?
        _ = try destination.storeAssetData(data, key: assetKey)
      }
    }
  }
}
