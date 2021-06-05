// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Combine
import Foundation
import UniformTypeIdentifiers

enum OpenLibrary {
  /// A Combine publisher that downloads a medium-sized cover image for a book from OpenLibrary.
  static func coverImagePublisher(isbn: String) -> AnyPublisher<TypedData, Error> {
    guard let url = URL(string: "https://covers.openlibrary.org/b/isbn/\(isbn)-M.jpg") else {
      return Fail<TypedData, Error>(error: URLError(.badURL)).eraseToAnyPublisher()
    }
    return URLSession.shared.dataTaskPublisher(for: url)
      .tryMap { data, response in
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
          throw URLError(.badServerResponse)
        }
        if let mimeType = httpResponse.mimeType, let type = UTType(mimeType: mimeType) {
          return TypedData(data: data, type: type)
        }
        if let image = UIImage(data: data), let jpegData = image.jpegData(compressionQuality: 0.8) {
          return TypedData(data: jpegData, type: .jpeg)
        }
        throw URLError(.cannotDecodeRawData)
      }
      .eraseToAnyPublisher()
  }
}
