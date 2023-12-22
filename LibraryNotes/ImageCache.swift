// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

// Workaround -- https://forums.swift.org/t/are-existential-types-sendable/58946
@preconcurrency import Foundation
import UIKit

/// A simple in-memory image cache, backed with `NSCache`
@MainActor
public final class ImageCache {
  public enum Error: Swift.Error {
    case unknownError
  }

  private let cache = NSCache<NSURL, UIImage>()

  /// Gets an image from a URL.
  /// - parameter url: The URL to load
  /// - parameter completion: Called upon getting the image. If the image is in the cache this is called synchronously. Otherwise, it will be called asynchronously on the main thread.
  public func image(for url: URL) async throws -> UIImage {
    let url = url.asSecureURL()
    let nsURL = url as NSURL
    if let cachedImage = cache.object(forKey: nsURL) {
      return cachedImage
    }
    let (data, _) = try await URLSession.shared.data(from: url)
    if let image = UIImage(data: data) {
      cache.setObject(image, forKey: nsURL)
      return image
    } else {
      throw Error.unknownError
    }
  }
}

private extension URL {
  /// If this is an http url, convert it to https
  func asSecureURL() -> URL {
    guard var components = URLComponents(string: absoluteString) else { return self }
    if components.scheme == "http" {
      components.scheme = "https"
    }
    return components.url!
  }
}
