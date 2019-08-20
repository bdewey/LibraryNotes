// Copyright © 2017-present Brian's Brain. All rights reserved.

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
    return lazy .map { byte in
      (byte <= 0xF ? "0" : "") + String(byte, radix: 16)
    }.joined()
  }
}

public extension String {
  /// Returns the SHA-1 digest of this string in UTF-8 encoding.
  func sha1Digest() -> String {
    return data(using: .utf8)!.sha1Digest()
  }
}
