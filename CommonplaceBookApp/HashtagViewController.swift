// Copyright © 2017-present Brian's Brain. All rights reserved.

import CommonplaceBook
import IGListKit
import UIKit

public protocol HashtagViewControllerDelegate: class {
  func hashtagViewController(_ viewController: HashtagViewController, didTap hashtag: String)
  func hashtagViewControllerDidClearHashtag(_ viewController: HashtagViewController)
  func hashtagViewControllerDidCancel(_ viewController: HashtagViewController)
}

public final class HashtagViewController: UIViewController {
  public init(index: NoteBundleDocument, stylesheet: Stylesheet) {
    self.dataSource = HashtagDataSource(document: index, stylesheet: stylesheet)
    self.stylesheet = stylesheet
    super.init(nibName: nil, bundle: nil)
    self.dataSource.delegate = self
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    dataSource.document.removeObserver(documentListAdapter)
  }

  private let dataSource: HashtagDataSource
  private let stylesheet: Stylesheet
  public weak var delegate: HashtagViewControllerDelegate?

  private lazy var documentListAdapter: ListAdapter = {
    let updater = ListAdapterUpdater()
    let adapter = ListAdapter(updater: updater, viewController: self)
    adapter.dataSource = dataSource
    dataSource.document.addObserver(adapter)
    return adapter
  }()

  private lazy var collectionView: UICollectionView = {
    let collectionView = UICollectionView(
      frame: .zero,
      collectionViewLayout: UICollectionViewFlowLayout()
    )
    collectionView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    collectionView.backgroundColor = stylesheet.colors.surfaceColor
    documentListAdapter.collectionView = collectionView
    return collectionView
  }()

  public override func loadView() {
    let shadowView = ShadowView()
    shadowView.shadowElevation = .menu
    view = shadowView
  }

  public override func viewDidLoad() {
    view.addSubview(collectionView)
  }
}

extension HashtagViewController: HashtagDataSourceDelegate {
  public func hashtagDataSourceDidClearHashtag() {
    delegate?.hashtagViewControllerDidClearHashtag(self)
  }

  public func hashtagDataSourceDidSelectHashtag(_ hashtag: String) {
    delegate?.hashtagViewController(self, didTap: hashtag)
  }
}
