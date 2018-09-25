// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import CoreServices
import FlashcardKit
import IGListKit
import MaterialComponents
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

  private lazy var layout: UICollectionViewFlowLayout = {
    let layout = UICollectionViewFlowLayout()
    layout.scrollDirection = .vertical
    layout.minimumInteritemSpacing = 0
    layout.minimumLineSpacing = 0
    return layout
  }()

  private let dataSource = DocumentDataSource()

  private lazy var adapter: ListAdapter = {
    let updater = ListAdapterUpdater()
    let adapter = ListAdapter(updater: updater, viewController: self)
    adapter.dataSource = dataSource
    adapter.scrollViewDelegate = self
    dataSource.adapter = adapter
    return adapter
  }()

  private lazy var collectionView: UICollectionView = {
    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: self.layout)
    collectionView.register(
      DocumentCollectionViewCell.self,
      forCellWithReuseIdentifier: reuseIdentifier
    )
    collectionView.backgroundColor = Stylesheet.default.colorScheme.surfaceColor
    adapter.collectionView = collectionView
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
    metadataQuery = MetadataQuery(predicate: predicate, delegate: dataSource)
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
      var pathComponent = "\(day).deck"
      var counter = 0
      var url = CommonplaceBook.ubiquityContainerURL.appendingPathComponent(pathComponent)
      while (try? url.checkPromisedItemIsReachable()) ?? false {
        counter += 1
        pathComponent = "\(day) \(counter).deck"
        url = CommonplaceBook.ubiquityContainerURL.appendingPathComponent(pathComponent)
      }
      LanguageDeck.open(at: pathComponent, completion: { (result) in
        _ = result.flatMap({ (deck) -> Void in
          deck.document.save(to: url, for: .forCreating, completionHandler: { (success) in
            print(success)
          })
        })
      })
    }
  }
}

extension DocumentListViewController: UICollectionViewDelegate {

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
