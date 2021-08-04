//
//  JSONEncoders.swift
//  JSONEncoders
//
//  Created by Brian Dewey on 8/4/21.
//  Copyright © 2021 Brian's Brain. All rights reserved.
//

import Foundation

extension JSONEncoder {
  static let databaseEncoder: JSONEncoder = {
    var encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }()
}

extension JSONDecoder {
  static let databaseDecoder: JSONDecoder = {
    var decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()
}

