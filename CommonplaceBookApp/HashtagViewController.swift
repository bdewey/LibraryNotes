// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import IGListKit
import UIKit

private let reuseIdentifier = "HACKY_document"

public protocol HashtagViewControllerDelegate: class {
  func hashtagViewControllerDidCancel(_ viewController: HashtagViewController)
}

public final class HashtagViewController: UIViewController {
  public init(dataSource: HashtagDataSource, stylesheet: Stylesheet) {
    self.dataSource = dataSource
    self.stylesheet = stylesheet
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let dataSource: HashtagDataSource
  private let stylesheet: Stylesheet
  public weak var delegate: HashtagViewControllerDelegate?

  private lazy var documentListAdapter: ListAdapter = {
    let updater = ListAdapterUpdater()
    let adapter = ListAdapter(updater: updater, viewController: self)
    adapter.dataSource = dataSource
    dataSource.adapter = adapter
    return adapter
  }()

  private lazy var collectionView: UICollectionView = {
    let collectionView = UICollectionView(
      frame: .zero,
      collectionViewLayout: UICollectionViewFlowLayout()
    )
    collectionView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    collectionView.register(
      DocumentCollectionViewCell.self,
      forCellWithReuseIdentifier: reuseIdentifier
    )
    collectionView.backgroundColor = stylesheet.colorScheme.darkSurfaceColor
    documentListAdapter.collectionView = collectionView
    return collectionView
  }()

  public override func loadView() {
    self.view = collectionView
  }

  public override func viewDidLoad() {
    let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTap))
    view.addGestureRecognizer(tapGestureRecognizer)
  }

  @objc private func didTap() {
    delegate?.hashtagViewControllerDidCancel(self)
  }
}
