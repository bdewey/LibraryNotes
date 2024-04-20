// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import UIKit

/// A list cell that is clear by default, with tint background color when selected.
final class ClearBackgroundCell: UICollectionViewListCell {
  override func updateConfiguration(using state: UICellConfigurationState) {
    var backgroundConfiguration = UIBackgroundConfiguration.clear()
    if state.isSelected {
      backgroundConfiguration.backgroundColor = nil
      backgroundConfiguration.backgroundColorTransformer = .init { $0.withAlphaComponent(0.5) }
    } else {
      backgroundConfiguration.backgroundColor = .grailSecondaryGroupedBackground
    }
    self.backgroundConfiguration = backgroundConfiguration
  }
}
