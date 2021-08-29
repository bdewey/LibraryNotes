//
//  ClearBackgroundCell.swift
//  ClearBackgroundCell
//
//  Created by Brian Dewey on 8/29/21.
//  Copyright © 2021 Brian's Brain. All rights reserved.
//

import UIKit

/// A list cell that is clear by default, with tint background color when selected.
internal final class ClearBackgroundCell: UICollectionViewListCell {
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


