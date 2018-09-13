//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

import Foundation

extension MetadataStorage {

  // TODO: The textbundle spec allows custom keys in info.json; support that.
  
  /// Textbundle metadata. See http://textbundle.org/spec/
  public struct Metadata: Codable, Equatable {
    
    /// Textbundle version
    public var version = 2
    
    /// The UTI of the text contents in the bundle.
    public var type: String? = "net.daringfireball.markdown"
    
    /// Flag indicating if the bundle is a temporary container solely for exchanging data between
    /// applications.
    public var transient: Bool?
    
    /// The URL of the application that originally created the textbundle.
    public var creatorURL: String?
    
    /// The bundle identifier of the application that created the file.
    public var creatorIdentifier: String?
    
    /// The URL of the file used to generate the bundle.
    public var sourceURL: String?
    
    public init() {
      // NOTHING
    }
    
    /// Creates a Metadata instance from JSON-encoded data.
    /// - throws: An error if any metadata field throws an error during decoding.
    public init(from data: Data) throws {
      let decoder = JSONDecoder()
      self = try decoder.decode(Metadata.self, from: data)
    }
    
    /// Returns a JSON-encoded representation of the metadata.
    /// - throws: An error if any metadata field throws an error during encoding.
    /// - returns: A new Data value containing the JSON-encoded representation of the metadata.
    public func makeData() throws -> Data {
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      return try encoder.encode(self)
    }
  }
}
