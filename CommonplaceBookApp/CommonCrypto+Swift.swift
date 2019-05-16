// Copyright © 2019 Brian's Brain. All rights reserved.

import CommonCrypto
import Foundation

public extension Data {
  /// Returns the SHA-1 digest of the contents of the data buffer.
  func sha1Digest() -> String {
    var digest = Data(repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))

    withUnsafeBytes { dataPtr -> Void in
      digest.withUnsafeMutableBytes({ digestPtr -> Void in
        CC_SHA1(dataPtr, CC_LONG(count), digestPtr)
      })
    }
    return digest.toHexString()
  }

  private func toHexString() -> String {
    return lazy.map { (byte) in
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
