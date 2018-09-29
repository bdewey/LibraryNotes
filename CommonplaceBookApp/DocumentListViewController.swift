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

final class DocumentListViewController: UIViewController, StylesheetContaining {

  init(stylesheet: Stylesheet) {
    self.stylesheet = stylesheet
    self.dataSource = DocumentDataSource(stylesheet: stylesheet)
    super.init(nibName: nil, bundle: nil)
    self.navigationItem.title = "Commonplace Book"
    self.navigationItem.rightBarButtonItem = newDocumentButton
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public let stylesheet: Stylesheet
  private let dataSource: DocumentDataSource

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

  private lazy var adapter: ListAdapter = {
    let updater = ListAdapterUpdater()
    let adapter = ListAdapter(updater: updater, viewController: self)
    adapter.dataSource = dataSource
    dataSource.adapter = adapter
    return adapter
  }()

  private lazy var collectionView: UICollectionView = {
    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: self.layout)
    collectionView.register(
      DocumentCollectionViewCell.self,
      forCellWithReuseIdentifier: reuseIdentifier
    )
    collectionView.backgroundColor = stylesheet.colorScheme.surfaceColor
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
