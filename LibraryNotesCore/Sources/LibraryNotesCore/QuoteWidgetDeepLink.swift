// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

/// The URL route used to open a quote from the Quote of the Day widget.
public struct QuoteWidgetDeepLink: Equatable, Sendable {
  public static let scheme = "dogeared"
  public static let host = "quote-of-the-day"

  public let noteId: String
  public let quoteKey: String

  public init(noteId: String, quoteKey: String) throws {
    guard !noteId.isEmpty, !quoteKey.isEmpty else {
      throw QuoteWidgetDeepLinkError.missingQuoteIdentifier
    }
    self.noteId = noteId
    self.quoteKey = quoteKey
  }

  public init(url: URL) throws {
    guard
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      components.scheme?.lowercased() == Self.scheme,
      components.host?.lowercased() == Self.host
    else {
      throw QuoteWidgetDeepLinkError.invalidRoute
    }
    let queryItems = components.queryItems ?? []
    guard
      let noteId = queryItems.first(where: { $0.name == "noteId" })?.value,
      let quoteKey = queryItems.first(where: { $0.name == "quoteKey" })?.value
    else {
      throw QuoteWidgetDeepLinkError.missingQuoteIdentifier
    }
    try self.init(noteId: noteId, quoteKey: quoteKey)
  }

  public var url: URL {
    var components = URLComponents()
    components.scheme = Self.scheme
    components.host = Self.host
    components.queryItems = [
      URLQueryItem(name: "noteId", value: noteId),
      URLQueryItem(name: "quoteKey", value: quoteKey),
    ]
    return components.url!
  }
}

public enum QuoteWidgetDeepLinkError: LocalizedError, Equatable {
  case invalidRoute
  case missingQuoteIdentifier

  public var errorDescription: String? {
    switch self {
    case .invalidRoute:
      "The URL is not a Quote of the Day link."
    case .missingQuoteIdentifier:
      "The Quote of the Day link does not identify a quote."
    }
  }
}
