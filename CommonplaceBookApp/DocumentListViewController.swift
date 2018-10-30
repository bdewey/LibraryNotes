// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import CoreServices
import FlashcardKit
import IGListKit
import MaterialComponents
import MiniMarkdown
import SnapKit
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

  init(parsingRules: ParsingRules, stylesheet: Stylesheet) {
    self.parsingRules = parsingRules
    self.stylesheet = stylesheet
    self.dataSource = DocumentDataSource(parsingRules: parsingRules, stylesheet: stylesheet)
    super.init(nibName: nil, bundle: nil)
    self.navigationItem.title = "Commonplace Book"
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let parsingRules: ParsingRules
  public let stylesheet: Stylesheet
  private let dataSource: DocumentDataSource

  private lazy var newDocumentButton: MDCButton = {
    let icon = UIImage(named: "baseline_add_black_24pt")?.withRenderingMode(.alwaysTemplate)
    let button = MDCFloatingButton(frame: .zero)
    button.setImage(icon, for: .normal)
    MDCFloatingActionButtonThemer.applyScheme(stylesheet.buttonScheme, to: button)
    button.addTarget(self, action: #selector(didTapNewDocument), for: .touchUpInside)
    return button
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
    collectionView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
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

  override func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(collectionView)
    view.addSubview(newDocumentButton)
    collectionView.frame = view.bounds
    newDocumentButton.snp.makeConstraints { (make) in
      make.trailing.equalToSuperview().offset(-16)
      make.bottom.equalToSuperview().offset(-16)
      make.width.equalTo(56)
      make.height.equalTo(56)
    }
    let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
      NSComparisonPredicate(conformingToUTI: "public.plain-text"),
      NSComparisonPredicate(conformingToUTI: "org.textbundle.package"),
      ])
    metadataQuery = MetadataQuery(predicate: predicate, delegate: dataSource)
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
