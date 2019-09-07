// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import Combine
import Foundation

/// Does an image search using Bing
public final class ImageSearchRequest: ObservableObject {
  /// What are we searching for?
  public var searchTerm = ""

  @Published var previousError: Error?
  @Published var images: Images?

  /// Initiates the search for the current search term.
  public func performSearch() {
    let request = makeRequest()
    previousError = nil
    let task = URLSession.shared.dataTask(with: request) { data, _, error in
      if let error = error {
        DDLogError("Error with image request: \(error)")
        self.previousError = error
        return
      }
      guard let data = data else {
        DDLogError("No data in response")
        return
      }
      DDLogInfo("Received image response: \(data.count) bytes")
      do {
        let images = try JSONDecoder().decode(Images.self, from: data)
        DDLogInfo("Decoded \(images.value.count) image(s)")
        DispatchQueue.main.async {
          self.images = images
        }
      } catch {
        DDLogError("Error decoding response: \(error)")
      }
    }
    task.resume()
  }

  public struct Images: Codable {
    let value: [Image]
  }

  public struct Image: Codable {
    let accentColor: String
    let contentSize: String
    let contentUrl: String
    let encodingFormat: String
    let height: Int
    let thumbnail: MediaSize
    let thumbnailUrl: String
    let width: Int
  }

  public struct MediaSize: Codable {
    let height: Int
    let width: Int
  }

  /// Azure image search endpiont
  private let endpoint = URL(string: "https://api.cognitive.microsoft.com/bing/v7.0/images/search")!

  /// Azure image search key.
  // TODO: This key shouldn't be built into the app.
  private let key = "e597b057bd4347deb1c2652ae110ae8f"

  private func makeRequest() -> URLRequest {
    var urlComponents = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
    urlComponents.queryItems = [
      URLQueryItem(name: "q", value: searchTerm),
      URLQueryItem(name: "aspect", value: "Square"),
      URLQueryItem(name: "licence", value: "Public"),
      URLQueryItem(name: "mkt", value: "es-MX"),
    ]
    var request = URLRequest(url: urlComponents.url!)
    request.addValue(key, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
    return request
  }
}
