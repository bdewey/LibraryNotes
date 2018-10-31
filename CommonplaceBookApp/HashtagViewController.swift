// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import UIKit

public protocol HashtagViewControllerDelegate: class {
  func hashtagViewControllerDidCancel(_ viewController: HashtagViewController)
}

public final class HashtagViewController: UIViewController {
  public init(stylesheet: Stylesheet) {
    self.stylesheet = stylesheet
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let stylesheet: Stylesheet
  public weak var delegate: HashtagViewControllerDelegate?

  public override func loadView() {
    let view = UIView(frame: .zero)
    view.backgroundColor = stylesheet.colorScheme.darkSurfaceColor
    self.view = view
  }

  public override func viewDidLoad() {
    let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTap))
    view.addGestureRecognizer(tapGestureRecognizer)
  }

  @objc private func didTap() {
    delegate?.hashtagViewControllerDidCancel(self)
  }
}
