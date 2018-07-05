// Copyright © 2018 Brian's Brain. All rights reserved.

import UIKit

import CommonplaceBook
import MaterialComponents

fileprivate let reuseIdentifier = "HACKY_document"

final class DocumentListViewController: UIViewController {
  
  private let commonplaceBook: CommonplaceBook
  
  private let appBar: MDCAppBar = {
    let appBar = MDCAppBar()
    MDCAppBarColorThemer.applySemanticColorScheme(Stylesheet.default.colorScheme, to: appBar)
    MDCAppBarTypographyThemer.applyTypographyScheme(Stylesheet.default.typographyScheme, to: appBar)
    return appBar
  }()
  
  private let dataSource: ArrayDataSource<URL> = ArrayDataSource {
    (url, collectionView, indexPath) -> UICollectionViewCell in
    let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: reuseIdentifier,
      for: indexPath
      ) as! DocumentCollectionViewCell
    cell.titleLabel.text = url.lastPathComponent
    return cell
  }
  
  init(commonplaceBook: CommonplaceBook) {
    self.commonplaceBook = commonplaceBook
    super.init(nibName: nil, bundle: nil)
    self.navigationItem.title = "Documents"
    self.addChild(appBar.headerViewController)
  }
  
  private lazy var layout: UICollectionViewFlowLayout = {
    let layout = UICollectionViewFlowLayout()
    layout.scrollDirection = .vertical
    layout.minimumInteritemSpacing = 0
    layout.minimumLineSpacing = 0
    return layout
  }()
  
  private lazy var collectionView: UICollectionView = {
    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: self.layout)
    collectionView.register(
      DocumentCollectionViewCell.self,
      forCellWithReuseIdentifier: reuseIdentifier
    )
    collectionView.dataSource = dataSource
    collectionView.delegate = self
    collectionView.backgroundColor = Stylesheet.default.colorScheme.surfaceColor
    return collectionView
  }()
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Lifecycle
  
  override func loadView() {
    self.view = collectionView
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    appBar.addSubviewsToParent()
    appBar.headerViewController.headerView.trackingScrollView = collectionView
    commonplaceBook.contents { (result) in
      switch result {
      case .success(let urls):
        self.dataSource.models = urls
        self.collectionView.reloadData()
      case .failure(let error):
        print("Unexpected error: \(error.localizedDescription)")
      }
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    layout.itemSize = CGSize(width: view.bounds.width, height: 48)
  }
  
  override func viewWillTransition(
    to size: CGSize,
    with coordinator: UIViewControllerTransitionCoordinator)
  {
    super.viewWillTransition(to: size, with: coordinator)
    layout.itemSize = CGSize(width: size.width, height: 48)
  }
}

extension DocumentListViewController: UICollectionViewDelegate {
  
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    self.navigationController?.pushViewController(TextEditViewController(), animated: true)
  }
  
  // MARK:- Forward scroll events on to the app bar.
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    appBar.headerViewController.headerView.trackingScrollDidScroll()
  }
  
  func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    appBar.headerViewController.headerView.trackingScrollDidEndDecelerating()
  }
  
  func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    appBar.headerViewController.headerView.trackingScrollDidEndDraggingWillDecelerate(decelerate)
  }
  
  func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    appBar.headerViewController.headerView.trackingScrollWillEndDragging(withVelocity: velocity, targetContentOffset: targetContentOffset)
  }
}
