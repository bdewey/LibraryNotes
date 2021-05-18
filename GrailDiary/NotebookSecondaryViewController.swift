//
//  NotebookDetailViewController.swift
//  GrailDiary
//
//  Created by Brian Dewey on 5/17/21.
//  Copyright © 2021 Brian's Brain. All rights reserved.
//

import UIKit

/// View controllers that we show in the detail screen of the NotebookViewController conform to this protocol.
protocol NotebookSecondaryViewController {
  /// A string identifying the type of detail screen (editor, quotes)
  var notebookDetailType: String { get }

  /// Updates `userActivity` to participate in state restoration.
  func updateUserActivity(_ userActivity: NSUserActivity)
}
