// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

/// A simple in-memory image cache, backed with `NSCache`
public final class ImageCache {
  public enum Error: Swift.Error {
    case unknownError
  }

  private let cache = NSCache<NSURL, UIImage>()

  /// Gets an image from a URL.
  /// - parameter url: The URL to load
  /// - parameter completion: Called upon getting the image. If the image is in the cache this is called synchronously. Otherwise, it will be called asynchronously on the main thread.
  public func image(for url: URL, completion: @escaping (Result<UIImage, Swift.Error>) -> Void) {
    let url = url.asSecureURL()
    let nsURL = url as NSURL
    if let cachedImage = cache.object(forKey: nsURL) {
      completion(.success(cachedImage))
      return
    }
    let task = URLSession.shared.dataTask(with: URLRequest(url: url)) { data, _, error in
      DispatchQueue.main.async {
        if let data = data, let image = UIImage(data: data) {
          self.cache.setObject(image, forKey: nsURL)
          completion(.success(image))
        } else {
          completion(.failure(error ?? Error.unknownError))
        }
      }
    }
    task.resume()
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
