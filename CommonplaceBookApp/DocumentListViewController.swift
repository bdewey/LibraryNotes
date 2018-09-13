// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import CoreServices
import MaterialComponents
import SwipeCellKit
import UIKit

private let reuseIdentifier = "HACKY_document"

extension NSComparisonPredicate {
  fileprivate convenience init(conformingToUTI uti: String) {
    self.init(
      leftExpression: NSExpression(forKeyPath: "kMDItemContentTypeTree"),
      rightExpression: NSExpression(forConstantValue: uti),
      modifier: .any,
      type: .like,
      options: []
    )
  }
}

final class DocumentListViewController: UIViewController {

  init() {
    super.init(nibName: nil, bundle: nil)
    self.navigationItem.title = "Documents"
    self.navigationItem.rightBarButtonItem = newDocumentButton
    self.addChild(appBar.headerViewController)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let appBar: MDCAppBar = {
    let appBar = MDCAppBar()
    MDCAppBarColorThemer.applySemanticColorScheme(Stylesheet.default.colorScheme, to: appBar)
    MDCAppBarTypographyThemer.applyTypographyScheme(Stylesheet.default.typographyScheme, to: appBar)
    return appBar
  }()

  private let newDocumentButton: UIBarButtonItem = {
    return UIBarButtonItem(
      image: UIImage(named: "baseline_add_black_24pt")?.withRenderingMode(.alwaysTemplate),
      style: .plain,
      target: self,
      action: #selector(didTapNewDocument)
    )
  }()

  private lazy var dataSource: ArrayDataSource<FileMetadata> = {
    ArrayDataSource { [weak self](metadata, collectionView, indexPath) -> UICollectionViewCell in
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: reuseIdentifier,
        for: indexPath
      ) as! DocumentCollectionViewCell // swiftlint:disable:this force_cast
      cell.titleLabel.text = metadata.displayName
      cell.delegate = self
      return cell
    }
  }()

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

  var metadataQuery: MetadataQuery?

  // MARK: - Lifecycle

  override func loadView() {
    self.view = collectionView
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    appBar.addSubviewsToParent()
    appBar.headerViewController.headerView.trackingScrollView = collectionView
    let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
      NSComparisonPredicate(conformingToUTI: "public.plain-text"),
      NSComparisonPredicate(conformingToUTI: "org.textbundle.package"),
      ])
    metadataQuery = MetadataQuery(predicate: predicate, delegate: self)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    layout.itemSize = CGSize(width: view.bounds.width, height: 48)
  }

  override func viewWillTransition(
    to size: CGSize,
    with coordinator: UIViewControllerTransitionCoordinator
  ) {
    super.viewWillTransition(to: size, with: coordinator)
    layout.itemSize = CGSize(width: size.width, height: 48)
  }

  @objc private func didTapNewDocument() {
    DispatchQueue.global(qos: .default).async {
      let day = DayComponents(Date())
      var pathComponent = "\(day).txt"
      var counter = 0
      var url = CommonplaceBook.ubiquityContainerURL.appendingPathComponent(pathComponent)
      while (try? url.checkPromisedItemIsReachable()) ?? false {
        counter += 1
        pathComponent = "\(day) \(counter).txt"
        url = CommonplaceBook.ubiquityContainerURL.appendingPathComponent(pathComponent)
      }
      let document = PlainTextDocument(fileURL: url)
      document.save(to: url, for: .forCreating, completionHandler: { (success) in
        print(success)
      })
    }
    print("yo")
  }
}

extension DocumentListViewController: SwipeCollectionViewCellDelegate {
  func collectionView(
    _ collectionView: UICollectionView,
    editActionsForItemAt indexPath: IndexPath,
    for orientation: SwipeActionsOrientation
  ) -> [SwipeAction]? {
    guard orientation == .right else { return nil }

    let deleteAction = SwipeAction(style: .destructive, title: "Delete") { [weak self] action, indexPath in
      // handle action by updating model with deletion
      guard let model = self?.dataSource.models[indexPath.row] else { return }
      try? FileManager.default.removeItem(at: model.fileURL)
      self?.dataSource.models.remove(at: indexPath.row)
      self?.collectionView.reloadData()
      action.fulfill(with: .delete)
    }

    // TODO: customize the action appearance
    deleteAction.image = UIImage(named: "delete")
    deleteAction.hidesWhenSelected = true

    return [deleteAction]
  }
}

extension DocumentListViewController: UICollectionViewDelegate {

  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let metadata = dataSource.models[indexPath.row]
    self.navigationController?.pushViewController(
      TextEditViewController(fileMetadata: metadata),
      animated: true
    )
  }

  // MARK: - Forward scroll events on to the app bar.
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    appBar.headerViewController.headerView.trackingScrollDidScroll()
  }

  func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    appBar.headerViewController.headerView.trackingScrollDidEndDecelerating()
  }

  func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    appBar.headerViewController.headerView.trackingScrollDidEndDraggingWillDecelerate(decelerate)
  }

  func scrollViewWillEndDragging(
    _ scrollView: UIScrollView,
    withVelocity velocity: CGPoint,
    targetContentOffset: UnsafeMutablePointer<CGPoint>
  ) {
    appBar.headerViewController.headerView.trackingScrollWillEndDragging(
      withVelocity: velocity,
      targetContentOffset: targetContentOffset
    )
  }
}

extension DocumentListViewController: MetadataQueryDelegate {

  func metadataQuery(_ metadataQuery: MetadataQuery, didFindItems items: [NSMetadataItem]) {
    dataSource.models = items.map { FileMetadata(metadataItem: $0) }
    collectionView.reloadData()
  }
}
