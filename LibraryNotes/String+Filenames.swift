import Foundation

public extension String {
  func sanitized(maximumLength: Int = 32) -> String {
    // see for ressoning on charachrer sets https://superuser.com/a/358861
    var invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
      .union(.newlines)
      .union(.illegalCharacters)
      .union(.controlCharacters)
      .union(.punctuationCharacters)

    invalidCharacters.remove("-")

    let slice = self
      .components(separatedBy: invalidCharacters)
      .joined(separator: "")
      .prefix(maximumLength)
    return String(slice)
  }

  mutating func sanitize() -> Void {
    self = self.sanitized()
  }

  func whitespaceCondensed() -> String {
    return self.components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: "-")
  }

  mutating func condenseWhitespace() -> Void {
    self = self.whitespaceCondensed()
  }
}

