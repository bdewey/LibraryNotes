// Copyright © 2017-present Brian's Brain. All rights reserved.

import MaterialComponents.MaterialActivityIndicator
import SnapKit
import UIKit

public protocol LoadingViewControllerDelegate: class {
  func loadingViewControllerCycleColors(_ viewController: LoadingViewController) -> [UIColor]
}

/// Simple view controller that just displays an indeterminate progress indicator in the middle
/// of its view. Intended to be used for mock UI prior to loading real model data.
public final class LoadingViewController: UIViewController {
  public init(stylesheet: Stylesheet) {
    self.stylesheet = stylesheet
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public enum LoadingStyle {
    case error
    case loading
  }

  public var style = LoadingStyle.loading {
    didSet {
      updateUI()
    }
  }

  public weak var delegate: LoadingViewControllerDelegate?
  public let stylesheet: Stylesheet

  public override func viewDidLoad() {
    super.viewDidLoad()

    view.addSubview(activityIndicator)
    activityIndicator.snp.makeConstraints { make in
      make.center.equalToSuperview()
    }
    view.addSubview(errorImageView)
    errorImageView.snp.makeConstraints { make in
      make.center.equalToSuperview()
    }
    updateUI()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.200) {
      self.activityIndicator.startAnimating()
    }
    view.backgroundColor = stylesheet.colors.surfaceColor
    let cycleColors = delegate?.loadingViewControllerCycleColors(self)
      ?? [stylesheet.colors.primaryColor]
    activityIndicator.cycleColors = cycleColors
  }

  private func updateUI() {
    activityIndicator.isHidden = style != .loading
    errorImageView.isHidden = style != .error
  }

  private lazy var activityIndicator: MDCActivityIndicator = {
    let activityIndicator = MDCActivityIndicator()
    activityIndicator.sizeToFit()
    return activityIndicator
  }()

  private lazy var errorImageView: UIImageView = {
    let image = UIImage(systemName: "xmark.octagon.fill")
    return UIImageView(image: image)
  }()
}
