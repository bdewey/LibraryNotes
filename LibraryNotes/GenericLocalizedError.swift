//  Copyright © 2022 Brian's Brain. All rights reserved.

import Foundation

public struct GenericLocalizedError: Error, LocalizedError {
  public let errorDescription: String?
}
