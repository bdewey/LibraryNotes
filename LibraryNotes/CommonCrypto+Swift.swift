// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import CommonCrypto
import CryptoKit
import Foundation

public extension DataProtocol {
  /// Returns the SHA-1 digest of the contents of the data buffer.
  func sha1Digest() -> String {
    let digest = Insecure.SHA1.hash(data: self)
    return Data(digest).toHexString()
  }

  func toHexString() -> String {
    lazy.map { byte in
      (byte <= 0xF ? "0" : "") + String(byte, radix: 16)
    }.joined()
  }
}

public extension String {
  /// Returns the SHA-1 digest of this string in UTF-8 encoding.
  func sha1Digest() -> String {
    data(using: .utf8)!.sha1Digest()
  }
}
