//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

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
