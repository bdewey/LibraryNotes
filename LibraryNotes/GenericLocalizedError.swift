// Copyright (c) 2018-2025  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

public struct GenericLocalizedError: Error, LocalizedError {
  public let errorDescription: String?

  public init(errorDescription: String?) {
    self.errorDescription = errorDescription
  }
}
