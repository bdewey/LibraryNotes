// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

public enum GoogleBooks {
  struct Response: Codable {
    var totalItems: Int
    var items: [Item]
  }

  struct Item: Codable {
    var id: String
    var volumeInfo: VolumeInfo
  }

  struct VolumeInfo: Codable {
    var title: String
    var subtitle: String?
    var authors: [String]?
    var publishedDate: String?
    var imageLinks: ImageLink?
  }

  struct ImageLink: Codable {
    var smallThumbnail: String?
    var thumbnail: String?
  }
}
