// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import CoreServices
import FlashcardKit
import IGListKit
import MaterialComponents
import MiniMarkdown
import SnapKit
import TextBundleKit
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

/// Implements a filterable list of documents in an interactive notebook.
final class DocumentListViewController: UIViewController, StylesheetContaining {

  /// Designated initializer.
  ///
  /// - note: This object will "own" `propertiesDocument`. No other class should
  ///         access this simultaneously, and the class will close the document when
  ///         it is deallocated.
  /// - parameter propertiesDocument: The cached extracted properties of all documents.
  /// - parameter studyHistory: A metadocument that contains the records of all study sessions.
  /// - parameter stylesheet: Controls the styling of UI elements.
  init(
    propertiesDocument: DocumentPropertiesIndexDocument,
    studyHistory: TextBundleDocument,
    stylesheet: Stylesheet
  ) {
    // This is a hack -- just trying to experiment with the Notebook interface.
    self.notebook = ICloudFileMetadataProvider(container: propertiesDocument.fileURL.deletingLastPathComponent())
    self.propertiesDocument = propertiesDocument
    self.studyHistory = studyHistory
    self.stylesheet = stylesheet
    self.dataSource = DocumentDataSource(index: propertiesDocument.index, stylesheet: stylesheet)
    super.init(nibName: nil, bundle: nil)
    self.navigationItem.title = "Interactive Notebook"
    self.navigationItem.leftBarButtonItem = hashtagMenuButton
    self.navigationItem.rightBarButtonItem = studyButton
    self.studyMetadataSubscription = studyHistory
      .containerStudyMetadata
      .subscribe { (taggedMetadataResult) in
        self.currentDocumentNameToIdentifierToMetadata = taggedMetadataResult.value?.value
          ?? [String: [String: StudyMetadata]]()
      }
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// Performs necessary cleanup tasks: Closing the index, deregisters the adapter.
  deinit {
    propertiesDocument.close(completionHandler: nil)

    dataSource.index.removeListener(documentListAdapter)
  }

  private let notebook: ICloudFileMetadataProvider
  private let propertiesDocument: DocumentPropertiesIndexDocument
  private let studyHistory: TextBundleDocument
  public let stylesheet: Stylesheet
  private let dataSource: DocumentDataSource
  private var studyMetadataSubscription: AnySubscription?
  private var currentDocumentNameToIdentifierToMetadata = [String: [String: StudyMetadata]]() {
    didSet { configureUI() }
  }

  private lazy var hashtagMenuButton: UIBarButtonItem = {
    return UIBarButtonItem(
      image: UIImage(named: "round_menu_black_24pt")?.withRenderingMode(.alwaysTemplate),
      style: .plain,
      target: self,
      action: #selector(didTapHashtagMenu)
    )
  }()

  private lazy var newDocumentButton: MDCButton = {
    let icon = UIImage(named: "baseline_add_black_24pt")?.withRenderingMode(.alwaysTemplate)
    let button = MDCFloatingButton(frame: .zero)
    button.setImage(icon, for: .normal)
    MDCFloatingActionButtonThemer.applyScheme(stylesheet.buttonScheme, to: button)
    button.addTarget(self, action: #selector(didTapNewDocument), for: .touchUpInside)
    return button
  }()

  private lazy var studyButton: UIBarButtonItem = {
    return UIBarButtonItem(
      title: "Study",
      style: .plain,
      target: self,
      action: #selector(startStudySession)
    )
  }()

  private lazy var layout: UICollectionViewFlowLayout = {
    let layout = UICollectionViewFlowLayout()
    layout.scrollDirection = .vertical
    layout.minimumInteritemSpacing = 0
    layout.minimumLineSpacing = 0
    return layout
  }()

  // TODO: Code smell here
  private lazy var documentListAdapter: ListAdapter = {
    let updater = ListAdapterUpdater()
    let adapter = ListAdapter(updater: updater, viewController: self)
    adapter.dataSource = dataSource
    dataSource.index.addListener(adapter)
    return adapter
  }()

  private lazy var documentCollectionView: UICollectionView = {
    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: self.layout)
    collectionView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    collectionView.register(
      DocumentCollectionViewCell.self,
      forCellWithReuseIdentifier: reuseIdentifier
    )
    collectionView.backgroundColor = stylesheet.colorScheme.surfaceColor
    documentListAdapter.collectionView = collectionView
    return collectionView
  }()

  var metadataQuery: MetadataQuery?

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(documentCollectionView)
    view.addSubview(newDocumentButton)
    documentCollectionView.frame = view.bounds
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
    metadataQuery = MetadataQuery(predicate: predicate, delegate: propertiesDocument.index)
    configureUI()
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

  private var hamburgerPresentationController: CoverPartiallyPresentationController?

  private func configureUI() {
    studyButton.isEnabled = !dataSource.studySession(metadata: currentDocumentNameToIdentifierToMetadata).isEmpty
  }

  @objc private func didTapHashtagMenu() {
    let hashtagViewController = HashtagViewController(
      index: propertiesDocument.index,
      stylesheet: stylesheet
    )
    hamburgerPresentationController = CoverPartiallyPresentationController(
      presentedViewController: hashtagViewController,
      presenting: self,
      coverDirection: .left
    )
    hashtagViewController.transitioningDelegate = hamburgerPresentationController
    hashtagViewController.modalPresentationStyle = .custom
    hashtagViewController.delegate = self
    present(hashtagViewController, animated: true, completion: nil)
  }

  @objc private func startStudySession() {
    let studyVC = StudyViewController(
      studySession: dataSource.studySession(metadata: currentDocumentNameToIdentifierToMetadata),
      documentCache: ReadOnlyDocumentCache(delegate: self),
      stylesheet: stylesheet,
      delegate: self
    )
    studyVC.modalTransitionStyle = .crossDissolve
    present(studyVC, animated: true, completion: nil)
  }
}

extension DocumentListViewController: HashtagViewControllerDelegate {
  func hashtagViewControllerDidClearHashtag(_ viewController: HashtagViewController) {
    dataSource.filteredHashtag = nil
    documentListAdapter.performUpdates(animated: true)
    title = "Interactive Notebook"
    configureUI()
    dismiss(animated: true, completion: nil)
  }

  func hashtagViewController(_ viewController: HashtagViewController, didTap hashtag: String) {
    print("Tapped " + hashtag)
    dataSource.filteredHashtag = hashtag
    documentListAdapter.performUpdates(animated: true)
    title = hashtag
    configureUI()
    dismiss(animated: true, completion: nil)
  }

  func hashtagViewControllerDidCancel(_ viewController: HashtagViewController) {
    dismiss(animated: true, completion: nil)
  }
}

extension DocumentListViewController: ReadOnlyDocumentCacheDelegate {
  func documentCache(_ cache: ReadOnlyDocumentCache, documentFor name: String) -> UIDocument? {
    let fileURL = propertiesDocument.index.containerURL.appendingPathComponent(name)
    // TODO: Should I really do this based on path extension?
    switch fileURL.pathExtension {
    case "deck", "textbundle":
      return TextBundleDocument(fileURL: fileURL)
    default:
      return PlainTextDocument(fileURL: fileURL)
    }
  }
}

extension DocumentListViewController: StudyViewControllerDelegate {
  func studyViewController(
    _ studyViewController: StudyViewController,
    didFinishSession session: StudySession
  ) {
    studyHistory.containerStudyMetadata.update(with: session, on: Date())
    dismiss(animated: true, completion: nil)
  }

  func studyViewControllerDidCancel(_ studyViewController: StudyViewController) {
    dismiss(animated: true, completion: nil)
  }
}
