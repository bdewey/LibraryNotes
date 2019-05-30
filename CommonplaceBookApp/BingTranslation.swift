// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import TextBundleKit

private let encoder = JSONEncoder()
private let decoder = JSONDecoder()

final class BingTranslation: NSObject {
  public enum Error: Swift.Error {
    case cannotParseResponse
  }

  public enum Language: String {
    case english = "en"
    case spanish = "es"
  }

  private let key1 = "8f5ddefaab7448d49fe3a9027ab814f5"
  private let key2 = "f2c26a770044433389363e18734f1dc9"

  private let requestURL = URL(string: "https://api.cognitive.microsofttranslator.com/translate")!

  public func requestTranslation(
    of phrase: String,
    from sourceLanguage: Language,
    to destinationLanguage: Language,
    completion: @escaping (Result<String>) -> Void
  ) {
    var urlComponents = URLComponents(url: requestURL, resolvingAgainstBaseURL: false)!
    urlComponents.queryItems = [
      URLQueryItem(name: "api-version", value: "3.0"),
      URLQueryItem(name: "from", value: sourceLanguage.rawValue),
      URLQueryItem(name: "to", value: destinationLanguage.rawValue),
    ]
    var request = URLRequest(url: urlComponents.url!)
    request.httpMethod = "POST"
    let phrases = [RequestText(phrase)]
    let dataResult = Result<Data> { try encoder.encode(phrases) }
    guard case .success(let data) = dataResult else {
      let stringResult = dataResult.flatMap { _ in "" }
      completion(stringResult)
      return
    }
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(String(data.count), forHTTPHeaderField: "Content-Length")
    request.setValue(key1, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")

    let completeOnMainThread = { (result: Result<String>) in
      if Thread.isMainThread {
        completion(result)
      } else {
        DispatchQueue.main.async {
          completion(result)
        }
      }
    }

    URLSession.shared.uploadTask(with: request, from: data) { responseData, response, error in
      if let error = error {
        completeOnMainThread(.failure(error))
      } else if let responseData = responseData {
        if let response = try? decoder.decode([Response].self, from: responseData),
          let firstPhraseTranslation = response.first,
          let firstTranslation = firstPhraseTranslation.translations.first {
          completeOnMainThread(.success(firstTranslation.text.lowercased()))
        } else {
          completeOnMainThread(.failure(Error.cannotParseResponse))
        }
      }
    }.resume()
  }
}

extension BingTranslation {
  struct RequestText: Codable {
    // TODO: Change to lowercase and modify the JSON encoding to use uppercase
    let Text: String // swiftlint:disable:this identifier_name

    init(_ text: String) {
      self.Text = text
    }
  }
}

extension BingTranslation {
  struct Response: Codable {
    let translations: [ResponseTranslation]
  }

  struct ResponseTranslation: Codable {
    let to: String // swiftlint:disable:this identifier_name
    let text: String
  }
}
