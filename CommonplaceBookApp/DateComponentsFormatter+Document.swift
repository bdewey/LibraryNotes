// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation

public extension DateComponentsFormatter {
  /// Shows the age of a page in a document list view.
  static let age: DateComponentsFormatter = {
    let ageFormatter = DateComponentsFormatter()
    ageFormatter.maximumUnitCount = 1
    ageFormatter.unitsStyle = .abbreviated
    ageFormatter.allowsFractionalUnits = false
    ageFormatter.allowedUnits = [.day, .hour, .minute]
    return ageFormatter
  }()
}
