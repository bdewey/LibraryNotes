// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import MaterialComponents.MaterialActivityIndicator
import SnapKit
import UIKit

/// Simple view controller that just displays an indeterminate progress indicator in the middle
/// of its view. Intended to be used for mock UI prior to loading real model data.
public final class LoadingViewController: UIViewController {

  public var stylesheet: Stylesheet? {
    didSet {
      if isViewLoaded { configureUI() }
    }
  }

  public override func viewDidLoad() {
    super.viewDidLoad()

    view.addSubview(activityIndicator)
    activityIndicator.snp.makeConstraints { (make) in
      make.center.equalToSuperview()
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.200) {
      self.activityIndicator.startAnimating()
    }
    configureUI()
  }

  private func configureUI() {
    if let stylesheet = stylesheet {
      MDCActivityIndicatorColorThemer.applySemanticColorScheme(
        stylesheet.colorScheme,
        to: activityIndicator
      )
    }
  }

  private lazy var activityIndicator: MDCActivityIndicator = {
    let activityIndicator = MDCActivityIndicator()
    activityIndicator.sizeToFit()
    return activityIndicator
  }()
}
