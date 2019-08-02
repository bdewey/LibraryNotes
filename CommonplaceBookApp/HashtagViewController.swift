// Copyright © 2017-present Brian's Brain. All rights reserved.

import UIKit

public protocol HashtagViewControllerDelegate: class {
  func hashtagViewController(_ viewController: HashtagViewController, didTap hashtag: String)
  func hashtagViewControllerDidClearHashtag(_ viewController: HashtagViewController)
  func hashtagViewControllerDidCancel(_ viewController: HashtagViewController)
}

public final class HashtagViewController: UIViewController {
  public init(index: NoteArchiveDocument, stylesheet: Stylesheet) {
    self.notebook = index
    self.stylesheet = stylesheet
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let notebook: NoteArchiveDocument
  private var hashtagDataController: HashtagDataController!
  private let stylesheet: Stylesheet
  public weak var delegate: HashtagViewControllerDelegate?

  private lazy var tableView: UITableView = {
    let tableView = UITableView(frame: .zero, style: .plain)
    tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    tableView.backgroundColor = stylesheet.colors.surfaceColor
    tableView.separatorStyle = .none
    return tableView
  }()

  public override func viewDidLoad() {
    hashtagDataController = HashtagDataController(tableView: tableView, notebook: notebook, stylesheet: stylesheet)
    hashtagDataController.delegate = self
    view.addSubview(tableView)
  }

  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    hashtagDataController.performUpdates(animated: false)
    hashtagDataController.startObservingNotebook()
  }

  public override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    hashtagDataController.stopObservingNotebook()
  }
}

extension HashtagViewController: HashtagDataControllerDelegate {
  public func hashtagDataControllerDidClearHashtag() {
    delegate?.hashtagViewControllerDidClearHashtag(self)
  }

  public func hashtagDataControllerDidSelectHashtag(_ hashtag: String) {
    delegate?.hashtagViewController(self, didTap: hashtag)
  }
}
