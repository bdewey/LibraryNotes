// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import Combine
import GRDB
import Logging
import SnapKit
import UIKit

protocol NotebookStructureViewControllerDelegate: AnyObject {
  func notebookStructureViewController(_ viewController: NotebookStructureViewController, didSelect structure: NotebookStructureViewController.StructureIdentifier)
  func notebookStructureViewControllerDidRequestChangeFocus(_ viewController: NotebookStructureViewController)
}

/// Displays a list of any "structure" inside the notebook -- currently just hashtags
final class NotebookStructureViewController: UIViewController {
  /// What subset of notebook pages does the person want to see?
  enum StructureIdentifier: Hashable, CustomStringConvertible, RawRepresentable {
    case trash
    case hashtag(String)

    case wantToRead
    case currentlyReading
    case read

    /// The raw value is used to serialize the focused element for state restoration.
    init?(rawValue: String) {
      switch rawValue {
      case "##all##":
        self = .read
      case "##inbox##":
        self = .wantToRead
      case "##trash##":
        self = .trash
      case "##currentlyReading##":
        self = .currentlyReading
      default:
        self = .hashtag(rawValue)
      }
    }

    var rawValue: String {
      switch self {
      case .trash:
        return "##trash##"
      case .wantToRead:
        return "##inbox##"
      case .currentlyReading:
        return "##currentlyReading##"
      case .read:
        return "##all##"
      case .hashtag(let hashtag):
        return hashtag
      }
    }

    var description: String {
      switch self {
      case .trash: return "Trash"
      case .wantToRead: return "Want to read"
      case .currentlyReading: return "Currently reading"
      case .read: return "My Books"
      case .hashtag(let hashtag): return String(hashtag.split(separator: "/").last!)
      }
    }

    var longDescription: String {
      switch self {
      case .trash: return "Trash"
      case .wantToRead: return "Want to read"
      case .currentlyReading: return "Currently reading"
      case .read: return "My Books"
      case .hashtag(let hashtag): return hashtag
      }
    }

    var predefinedFolder: PredefinedFolder? {
      switch self {
      case .hashtag, .read: return nil
      case .trash: return .recentlyDeleted
      case .wantToRead: return .wantToRead
      case .currentlyReading: return .currentlyReading
      }
    }

    var hashtag: String? {
      guard case .hashtag(let hashtag) = self else {
        return nil
      }
      return hashtag
    }

    var query: QueryInterfaceRequest<NoteMetadataRecord> {
      if case .hashtag(let hashtag) = self {
        let hashtagRequest = NoteRecord
          .joining(
            required: NoteRecord.noteHashtags
              .filter(NoteLinkRecord.Columns.targetTitle.like("\(hashtag)/%") || NoteLinkRecord.Columns.targetTitle.like("\(hashtag)"))
          )
        return NoteMetadataRecord.request(baseRequest: hashtagRequest)
          .filter(NoteRecord.Columns.folder == nil || NoteRecord.Columns.folder != PredefinedFolder.recentlyDeleted.rawValue)
      } else {
        return NoteMetadataRecord.request()
          .filter(NoteRecord.Columns.folder == nil || NoteRecord.Columns.folder != PredefinedFolder.recentlyDeleted.rawValue)
      }
    }

    /// A filter function that returns true if `metadata` is included in this structure.
    func filterBookNoteMetadata(tuple: (key: String, value: BookNoteMetadata)) -> Bool {
      let metadata = tuple.value
      switch self {
      case .hashtag(let hashtag):
        return metadata.tags.contains(hashtag)
      case .trash:
        return metadata.folder == PredefinedFolder.recentlyDeleted.rawValue
      default:
        return true
      }
    }
  }

  /// Sections of our list.
  private enum Section: CaseIterable {
    // Section that holds "Inbox"
    case notePrefix
    // Section that holds "Notes"
    case notes
    // Holds Archive & Trash
    case noteSuffix
  }

  /// Item identifier -- this is separate from StructureIdentifier because we need to know if we have children for the disclosure indicator
  private struct Item: Hashable, CustomStringConvertible {
    var structureIdentifier: StructureIdentifier
    var hasChildren: Bool
    var image: UIImage?

    var description: String { structureIdentifier.description }
    static let trash = Item(structureIdentifier: .trash, hasChildren: false, image: UIImage(systemName: "trash"))

    static let wantToRead = Item(structureIdentifier: .wantToRead, hasChildren: false, image: UIImage(systemName: "list.star"))
    static let currentlyReading = Item(structureIdentifier: .currentlyReading, hasChildren: false, image: UIImage(systemName: "book"))
    static let read = Item(structureIdentifier: .read, hasChildren: true, image: UIImage(systemName: "books.vertical"))
  }

  public init(database: NoteDatabase) {
    self.database = database
    super.init(nibName: nil, bundle: nil)
    title = AppDelegate.appName
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public weak var delegate: NotebookStructureViewControllerDelegate?
  private let database: NoteDatabase
  private var notebookSubscription: AnyCancellable?
  private var progressView: UIProgressView? {
    didSet {
      configureToolbar()
    }
  }

  private lazy var collectionView: UICollectionView = {
    let layout = UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in
      var config = UICollectionLayoutListConfiguration(appearance: .sidebar)
      config.backgroundColor = .grailBackground
      // the first section has no header; everything else gets a header.
      config.headerMode = .none
      // The last section gets a footer
      config.footerMode = (sectionIndex == Section.allCases.count - 1) ? .supplementary : .none
      let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
      return section
    }
    let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
    view.delegate = self
    return view
  }()

  private let footerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionFooter) { footerView, _, _ in
    var footerConfiguration = footerView.defaultContentConfiguration()
    footerConfiguration.text = "Version \(UIApplication.versionString)"
    footerConfiguration.textProperties.font = UIFont.preferredFont(forTextStyle: .caption1)
    footerConfiguration.textProperties.color = UIColor.secondaryLabel
    footerView.contentConfiguration = footerConfiguration
  }

  private lazy var dataSource: UICollectionViewDiffableDataSource<Section, Item> = {
    let hashtagRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, _, item in
      var contentConfiguration = cell.defaultContentConfiguration()
      contentConfiguration.text = item.description
      contentConfiguration.textProperties.color = .label
      contentConfiguration.image = item.image
      cell.contentConfiguration = contentConfiguration

      // Only items with children get an outline disclosure identifier.
      if item.hasChildren {
        cell.accessories = [.outlineDisclosure()]
      } else {
        cell.accessories = []
      }
    }

    let dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { (view, indexPath, item) -> UICollectionViewCell? in
      view.dequeueConfiguredReusableCell(using: hashtagRegistration, for: indexPath, item: item)
    }

    dataSource.supplementaryViewProvider = { [footerRegistration] collectionView, kind, indexPath in
      if kind == UICollectionView.elementKindSectionFooter {
        return collectionView.dequeueConfiguredReusableSupplementary(using: footerRegistration, for: indexPath)
      }
      Logger.shared.error("Unexpected supplementary kind \(kind), returning nil")
      return nil
    }
    return dataSource
  }()

  // MARK: - State restoration

  private enum ActivityKey {
    static let selectedItemIndex = "org.brians-brain.GrailDiary.NotebookStructureViewController.selectedItemIndex"
  }

  func updateUserActivity(_ activity: NSUserActivity) {
    guard
      let selectedIndexPath = collectionView.indexPathsForSelectedItems?.first,
      let itemIdentifier = dataSource.itemIdentifier(for: selectedIndexPath),
      let index = dataSource.snapshot().indexOfItem(itemIdentifier)
    else {
      return
    }
    activity.addUserInfoEntries(from: [ActivityKey.selectedItemIndex: index])
  }

  func configure(with activity: NSUserActivity) {
    updateSnapshot()
    let snapshot = dataSource.snapshot()
    guard
      let selectedIndex = activity.userInfo?[ActivityKey.selectedItemIndex] as? Int,
      let itemIdentifier = (selectedIndex < snapshot.numberOfItems) ? snapshot.itemIdentifiers[selectedIndex] : nil,
      let indexPath = dataSource.indexPath(for: itemIdentifier)
    else {
      return
    }
    collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
  }

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(collectionView)
    collectionView.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
    updateSnapshot()
    notebookSubscription = database.notesDidChange.receive(on: DispatchQueue.main).sink { [weak self] in
      self?.updateSnapshot()
    }
    navigationController?.setToolbarHidden(false, animated: false)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setToolbarHidden(false, animated: false)
    configureToolbar()
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    configureToolbar()
  }

  override var canBecomeFirstResponder: Bool { true }

  override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
    Logger.shared.debug("Handling keypress")
    var didHandleEvent = false
    for press in presses {
      guard let key = press.key else { continue }
      switch key.charactersIgnoringModifiers {
      case UIKeyCommand.inputDownArrow:
        moveSelectionDown()
        didHandleEvent = true
      case UIKeyCommand.inputUpArrow:
        moveSelectionUp()
        didHandleEvent = true
      case UIKeyCommand.inputRightArrow:
        expandSelection()
        didHandleEvent = true
      case UIKeyCommand.inputLeftArrow:
        collapseSelection()
        didHandleEvent = true
      case "\t", "\r":
        delegate?.notebookStructureViewControllerDidRequestChangeFocus(self)
        didHandleEvent = true
      default:
        break
      }
    }

    if !didHandleEvent {
      super.pressesBegan(presses, with: event)
    }
  }
}

// MARK: - Private

private extension NotebookStructureViewController {
  func moveSelectionDown() {
    let snapshot = dataSource.snapshot()
    guard snapshot.numberOfItems > 0 else { return }
    let nextItemIndex: Int
    if let indexPath = collectionView.indexPathsForSelectedItems?.first,
       let item = dataSource.itemIdentifier(for: indexPath),
       let itemIndex = snapshot.indexOfItem(item)
    {
      nextItemIndex = min(itemIndex + 1, snapshot.numberOfItems - 1)
    } else {
      nextItemIndex = 0
    }
    if let nextIndexPath = dataSource.indexPath(for: snapshot.itemIdentifiers[nextItemIndex]) {
      collectionView.selectItem(at: nextIndexPath, animated: true, scrollPosition: .top)
      selectItemAtIndexPath(nextIndexPath, shiftFocus: false)
    }
  }

  func moveSelectionUp() {
    let snapshot = dataSource.snapshot()
    guard snapshot.numberOfItems > 0 else { return }
    let previousItemIndex: Int
    if let indexPath = collectionView.indexPathsForSelectedItems?.first,
       let item = dataSource.itemIdentifier(for: indexPath),
       let itemIndex = snapshot.indexOfItem(item)
    {
      previousItemIndex = max(itemIndex - 1, 0)
    } else {
      previousItemIndex = snapshot.numberOfItems - 1
    }
    if let previousIndexPath = dataSource.indexPath(for: snapshot.itemIdentifiers[previousItemIndex]) {
      collectionView.selectItem(at: previousIndexPath, animated: true, scrollPosition: .bottom)
      selectItemAtIndexPath(previousIndexPath, shiftFocus: false)
    }
  }

  func expandSelection() {
    guard
      let selectedIndexPath = collectionView.indexPathsForSelectedItems?.first,
      let selectedItem = dataSource.itemIdentifier(for: selectedIndexPath),
      selectedItem.hasChildren
    else {
      return
    }
    var snapshot = dataSource.snapshot(for: .notes)
    snapshot.expand([selectedItem])
    dataSource.apply(snapshot, to: .notes, animatingDifferences: true)
  }

  func collapseSelection() {
    guard
      let selectedIndexPath = collectionView.indexPathsForSelectedItems?.first,
      let selectedItem = dataSource.itemIdentifier(for: selectedIndexPath)
    else {
      return
    }
    var snapshot = dataSource.snapshot(for: .notes)
    var newlySelectedItem: Item?
    if snapshot.isExpanded(selectedItem) {
      snapshot.collapse([selectedItem])
    } else if let parent = snapshot.parent(of: selectedItem) {
      snapshot.collapse([parent])
      newlySelectedItem = parent
    }
    dataSource.apply(snapshot, to: .notes, animatingDifferences: true)
    if let newlySelectedItem = newlySelectedItem, let indexPath = dataSource.indexPath(for: newlySelectedItem) {
      collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .top)
      selectItemAtIndexPath(indexPath, shiftFocus: false)
    }
  }

  func selectItemAtIndexPath(_ indexPath: IndexPath, shiftFocus: Bool) {
    if let item = dataSource.itemIdentifier(for: indexPath) {
      delegate?.notebookStructureViewController(self, didSelect: item.structureIdentifier)
      if shiftFocus {
        splitViewController?.show(.supplementary)
      }
    }
  }
}

// MARK: - UICollectionViewDelegate

extension NotebookStructureViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    if let item = dataSource.itemIdentifier(for: indexPath) {
      delegate?.notebookStructureViewController(self, didSelect: item.structureIdentifier)
    }
  }

  func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
    let item = dataSource.itemIdentifier(for: indexPath)
    guard case .hashtag(let hashtag) = item?.structureIdentifier else { return nil }
    return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self, database] _ in
      guard let self = self else { return nil }
      let rename = UIAction(title: "Rename \(hashtag)", image: UIImage(systemName: "square.and.pencil")) { _ in
        Logger.shared.debug("Rename \(hashtag)")
        let alert = UIAlertController(title: "Rename \(hashtag)", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
          textField.placeholder = "#new-hashtag"
        }
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
          guard var newHashtag = alert.textFields?.first?.text else {
            Logger.shared.info("No replacement text; skipping hashtag rename.")
            return
          }
          if newHashtag.first != "#" {
            newHashtag = "#\(newHashtag)"
          }
          Logger.shared.info("Replacing \(hashtag) with \(newHashtag)")
          do {
            try database.renameHashtag(
              hashtag,
              to: newHashtag,
              filter: { $0.tags.anySatisfy { noteLink in hashtag.isPathPrefix(of: noteLink) } }
            )
          } catch {
            Logger.shared.error("Error renaming hashtag: \(error)")
          }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.view.tintColor = .grailTint
        self.present(alert, animated: true, completion: nil)
      }
      return UIMenu(title: "", children: [rename])
    }
  }
}

// MARK: - Private

private extension UIBarButtonItem {
  static func documentBrowser() -> UIBarButtonItem {
    let button = UIBarButtonItem(title: "Open", style: .plain, target: nil, action: #selector(AppCommands.openNewFile))
    button.accessibilityIdentifier = "open-files"
    return button
  }
}

private extension NotebookStructureViewController {
  func configureToolbar() {
    var toolbarItems: [UIBarButtonItem] = [documentActionMenu(), .flexibleSpace()]
    if let progressView = progressView {
      toolbarItems.append(UIBarButtonItem(customView: progressView))
      toolbarItems.append(.flexibleSpace())
    }
    if splitViewController?.isCollapsed ?? false, let newNoteButton = notebookViewController?.makeNewNoteButtonItem() {
      toolbarItems.append(newNoteButton)
    }
    self.toolbarItems = toolbarItems
  }

  private func documentActionMenu() -> UIBarButtonItem {
    let openCommand = UICommand(title: "Open", image: UIImage(systemName: "doc"), action: #selector(AppCommands.openNewFile))
    let importLibraryThing = UIAction(title: "Bulk Import", image: UIImage(systemName: "arrow.down.doc")) { [weak self] _ in
      guard let self = self else { return }
      Logger.shared.info("Importing from LibraryThing")
      let bookImporterViewController = BookImporterViewController(database: self.database)
      bookImporterViewController.delegate = self
      self.present(bookImporterViewController, animated: true)
    }
    let export = (database as? LegacyNoteDatabase).flatMap { legacyNoteDatabase -> UIAction in
      UIAction(title: "Export") { [weak self] _ in
        self?.exportToKVCRDT(legacyNoteDatabase: legacyNoteDatabase)
      }
    }
    return UIBarButtonItem(
      image: UIImage(systemName: "ellipsis.circle"),
      menu: UIMenu(
        children: [
          openCommand,
          importLibraryThing,
          export,
        ].compactMap { $0 }
      )
    )
  }

  private func exportToKVCRDT(legacyNoteDatabase: LegacyNoteDatabase) {
    let exportedURL = legacyNoteDatabase.fileURL.deletingPathExtension().appendingPathExtension("kvcrdt")
    Logger.shared.info("Exporting to \(exportedURL.path)")
    do {
      try legacyNoteDatabase.exportToKVCRDT(exportedURL)
      let alert = UIAlertController(title: "Export Complete", message: "Export was successful", preferredStyle: .alert)
      let okAction = UIAlertAction(title: "OK", style: .default)
      alert.addAction(okAction)
      present(alert, animated: true)
    } catch {
      Logger.shared.error("Unexpected error exporting data: \(error)")
    }
  }

  func updateSnapshot() {
    let existingNoteSnapshot = dataSource.snapshot(for: .notes)
    let isNotesExpanded = existingNoteSnapshot.index(of: .read) == nil || existingNoteSnapshot.isExpanded(.read)
    let selectedItem = collectionView.indexPathsForSelectedItems?.first.flatMap { dataSource.itemIdentifier(for: $0) }
    var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
    snapshot.appendSections([.notes, .noteSuffix])
    snapshot.appendItems([.trash])
    dataSource.apply(snapshot)
    var noteSectionSnapshot = makeNoteSectionSnapshot()
    if isNotesExpanded {
      noteSectionSnapshot.expand([.read])
    }
    dataSource.apply(noteSectionSnapshot, to: .notes)
    if let item = selectedItem, let indexPath = dataSource.indexPath(for: item) {
      collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
    }
  }

  private func makeNoteSectionSnapshot() -> NSDiffableDataSourceSectionSnapshot<Item> {
    var snapshot = NSDiffableDataSourceSectionSnapshot<Item>()

    var root = Item.read
    let hashtags = (try? database.bookMetadata.values.hashtags) ?? []
    root.hasChildren = !hashtags.isEmpty
    snapshot.append([root])

    // Enumerate every hashtag and make sure there is an entry for the hashtag *and all prefixes*.
    // Denote that each prefix has children.
    //
    // This algorithm depends on database.hashtags being sorted, so we will never process a prefix *after* a more specific
    // string. E.g., things work if we process `#books` then `#books/2020`, but will break if we process `#books/2020` before
    // `#books`.
    var stringToItem = [String: Item]()
    for hashtag in hashtags {
      for (index, character) in hashtag.enumerated() where character == "/" {
        let prefix = String(hashtag.prefix(index))
        stringToItem[prefix] = Item(structureIdentifier: .hashtag(prefix), hasChildren: true)
      }
      stringToItem[hashtag] = Item(structureIdentifier: .hashtag(hashtag), hasChildren: false)
    }

    // Now make a snapshot item for everything in `stringToItem`. The only tricky part is for a multi-part
    // hashtag like `#books/2020`, we have to look up its parent `#books`... and again, this depends on the array
    // being sorted.
    for hashtag in stringToItem.keys.sorted() {
      let parent = hashtag
        .lastIndex(of: "/")
        .flatMap { String(hashtag.prefix(upTo: $0)) }
        .flatMap { stringToItem[$0] }
      snapshot.append([stringToItem[hashtag]!], to: parent ?? root)
    }
    return snapshot
  }
}

extension NotebookStructureViewController: BookImporterViewControllerDelegate {
  func bookImporter(_ bookImporter: BookImporterViewController, didStartImporting count: Int) {
    let progressView = UIProgressView(progressViewStyle: .bar)
    progressView.progress = 0
    self.progressView = progressView
  }

  func bookImporter(_ bookImporter: BookImporterViewController, didProcess partialCount: Int, of totalCount: Int) {
    progressView?.progress = Float(partialCount) / Float(totalCount)
  }

  func bookImporterDidFinishImporting(_ bookImporter: BookImporterViewController) {
    progressView = nil
  }
}

private extension NoteMetadataRecord {
  var guessYearRead: Int? {
    for link in noteLinks where link.targetTitle.hasPrefix("#books/") {
      let yearString = link.targetTitle.dropFirst(7)
      return Int(yearString)
    }
    return nil
  }
}
