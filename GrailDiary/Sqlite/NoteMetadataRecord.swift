// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import Foundation
import GRDB

public struct NoteMetadataRecord: Decodable, FetchableRecord {
  var id: Note.Identifier
  var title: String
  var creationTimestamp: Date
  var modifiedTimestamp: Date
  var deleted: Bool
  var folder: String?
  var noteLinks: [NoteLinkRecord]
  var contents: [ContentRecord]
  var thumbnailImage: [BinaryContentRecord]
  var summary: String?

  /// Includes all of the joins you need to get the base information for a NoteMetadataRecord.
  /// You can chain other filters on this.
  static func request(baseRequest: QueryInterfaceRequest<NoteRecord> = NoteRecord.all()) -> QueryInterfaceRequest<NoteMetadataRecord> {
    let referenceRecords = NoteRecord.contentRecords.filter(ContentRecord.Columns.role == ContentRole.reference.rawValue)
    let thumbnailImages = NoteRecord.binaryContentRecords.filter(BinaryContentRecord.Columns.role == ContentRole.embeddedImage.rawValue).forKey("thumbnailImage")
    return baseRequest
      .filter(NoteRecord.Columns.deleted == false)
      .including(all: NoteRecord.noteHashtags)
      .including(all: referenceRecords)
      .including(all: thumbnailImages)
      .asRequest(of: NoteMetadataRecord.self)
  }
}

public extension NoteMetadataRecord {
  var book: Book? {
    guard
      let bookContent = contents.first(where: { $0.mimeType == ApplicationMimeType.book.rawValue }),
      let book = try? JSONDecoder().decode(Book.self, from: bookContent.text.data(using: .utf8)!)
    else {
      return nil
    }
    return book
  }
}
