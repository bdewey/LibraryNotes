// Copyright © 2019 Brian's Brain. All rights reserved.

import Foundation

/// Holds image data & encoding
struct EncodedImage: CustomStringConvertible {
  /// Encoded image data
  let data: Data

  /// Image encoding (e.g., "jpeg", "png")
  let encoding: String

  /// Image width, in pixels
  let width: Int

  /// Image height, in pixels
  let height: Int

  var description: String {
    return "Image size: (width: \(width), height: \(height)). Encoding = \(encoding). Size = \(data.count)"
  }
}
