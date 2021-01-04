// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import SnapKit
import UIKit

/// Simple view controller that just displays an indeterminate progress indicator in the middle
/// of its view. Intended to be used for mock UI prior to loading real model data.
public final class LoadingViewController: UIViewController {
  public enum LoadingStyle {
    case error
    case loading
  }

  public var style = LoadingStyle.loading {
    didSet {
      updateUI()
    }
  }

  override public func viewDidLoad() {
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
    view.backgroundColor = UIColor.systemBackground
  }

  private func updateUI() {
    activityIndicator.isHidden = style != .loading
    errorImageView.isHidden = style != .error
  }

  private lazy var activityIndicator: UIActivityIndicatorView = {
    let activityIndicator = UIActivityIndicatorView(style: .large)
    activityIndicator.color = UIColor.systemBlue
    activityIndicator.sizeToFit()
    return activityIndicator
  }()

  private lazy var errorImageView: UIImageView = {
    let image = UIImage(systemName: "xmark.octagon.fill")
    return UIImageView(image: image)
  }()
}
