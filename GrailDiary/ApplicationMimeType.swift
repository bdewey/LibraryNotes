//
//  ApplicationMimeType.swift
//  GrailDiary
//
//  Created by Brian Dewey on 6/1/21.
//  Copyright © 2021 Brian's Brain. All rights reserved.
//

import Foundation

public enum ApplicationMimeType: String {
  /// Private MIME type for URLs.
  case url = "text/vnd.grail.url"

  /// MIME type for Book
  case book = "application/json;type=Book"
}

