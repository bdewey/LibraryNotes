// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import UniformTypeIdentifiers

public extension UTType {
  static let kvcrdt = UTType("org.brians-brain.kvcrdt") ?? UTType(exportedAs: "org.brians-brain.kvcrdt", conformingTo: .data)
  static let libnotes = UTType("org.brians-brain.libnotes") ?? UTType(exportedAs: "org.brians-brain.libnotes", conformingTo: .data)
}
