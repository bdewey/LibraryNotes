// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import Combine
import Logging
import SnapKit
import SwiftUI
import UIKit

private extension Logger {
  static let bookSearch: Logger = {
    var bookSearch = Logger(label: "org.brians-brain.BookSearch")
    bookSearch.logLevel = .info
    return bookSearch
  }()
}

public protocol BookEditDetailsViewControllerDelegate: AnyObject {
  /// The person selected a book.
  func bookSearchViewController(_ viewController: BookEditDetailsViewController, didSelect book: AugmentedBook, coverImage: UIImage?)

  /// The person canceled without selecting a book.
  /// (Note this is not guaranteed to be called with the pull-down presentation style)
  func bookSearchViewControllerDidCancel(_ viewController: BookEditDetailsViewController)

  /// The person skipped adding book details to a new note.
  func bookSearchViewControllerDidSkip(_ viewController: BookEditDetailsViewController)
}

public extension AugmentedBook {
  /// A blank book.
  static let blank = AugmentedBook(title: "", authors: [])
}

/// This view controller allows editing of book details and cover images.
///
/// In addition to manually editing fields, this view controller lets you search Google Books for book information.
@MainActor
public final class BookEditDetailsViewController: UIViewController {
  public init(apiKey: String, book: AugmentedBook = .blank, coverImage: UIImage? = nil, showSkipButton: Bool) {
    self.apiKey = apiKey
    self.showSkipButton = showSkipButton
    self.model = BookEditViewModel(book: book, coverImage: coverImage)
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public weak var delegate: BookEditDetailsViewControllerDelegate?
  private let apiKey: String
  private let showSkipButton: Bool

  public enum Error: Swift.Error {
    case invalidServerResponse
  }

  private lazy var searchController: UISearchController = {
    let searchController = UISearchController(searchResultsController: nil)
    searchController.searchBar.delegate = self
    searchController.searchBar.placeholder = "Search Google Books"
    searchController.searchBar.showsBookmarkButton = CaptureSessionManager.defaultVideoDevice != nil
    searchController.searchBar.setImage(UIImage(systemName: "barcode.viewfinder"), for: .bookmark, state: .normal)
    searchController.showsSearchResultsController = true
    searchController.searchBar.searchTextField.clearButtonMode = .whileEditing
    searchController.delegate = self
    return searchController
  }()

  private lazy var collectionView: UICollectionView = {
    var listConfiguration = UICollectionLayoutListConfiguration(appearance: .plain)
    listConfiguration.backgroundColor = .grailBackground
    let layout = UICollectionViewCompositionalLayout.list(using: listConfiguration)
    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    collectionView.delegate = self
    collectionView.backgroundColor = .grailBackground
    return collectionView
  }()

  private lazy var barcodeScannerViewController: BarcodeScannerViewController = {
    let viewController = BarcodeScannerViewController(nibName: nil, bundle: nil)
    viewController.delegate = self
    return viewController
  }()

  private lazy var dataSource: UICollectionViewDiffableDataSource<Int, SearchResultsViewModel> = {
    let bookRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, SearchResultsViewModel> { cell, _, viewModel in
      var configuration = cell.defaultContentConfiguration()
      if let year = viewModel.book.yearPublished {
        configuration.text = "\(viewModel.book.title) (\(year))"
      } else {
        configuration.text = viewModel.book.title
      }
      configuration.textProperties.color = .label
      configuration.secondaryText = viewModel.book.authors.joined(separator: ", ")
      configuration.secondaryTextProperties.color = .secondaryLabel
      configuration.image = viewModel.coverImage
      var backgroundConfiguration = UIBackgroundConfiguration.listPlainCell()
      backgroundConfiguration.backgroundColor = .grailBackground

      cell.contentConfiguration = configuration
      cell.backgroundConfiguration = backgroundConfiguration
    }

    return UICollectionViewDiffableDataSource<Int, SearchResultsViewModel>(collectionView: collectionView) { collectionView, indexPath, book in
      collectionView.dequeueConfiguredReusableCell(using: bookRegistration, for: indexPath, item: book)
    }
  }()

  private let imageCache = ImageCache()
  private var searchResultsViewModels = [SearchResultsViewModel]()
  private var model = BookEditViewModel(book: AugmentedBook(title: "", authors: []), coverImage: nil)
  private lazy var decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()

  private let activityView = UIActivityIndicatorView(style: .large)

  private func updateViewModels(_ viewModels: [SearchResultsViewModel]) {
    assert(Thread.isMainThread)
    isBatchUpdating = true
    self.searchResultsViewModels = viewModels
    for viewModel in viewModels {
      if let url = viewModel.coverImageURL {
        imageCache.image(for: url) { result in
          guard let image = try? result.get() else { return }
          self.setViewModelImage(image, key: viewModel.id)
        }
      }
    }
    isBatchUpdating = false
    updateSnapshot()
  }

  private func setViewModelImage(_ image: UIImage, key: UUID) {
    assert(Thread.isMainThread)
    guard let index = searchResultsViewModels.firstIndex(where: { $0.id == key }) else { return }
    searchResultsViewModels[index].coverImage = image
    updateSnapshot()
  }

  /// A flag to avoid unnecessary collection view snapshot generation when populating the initial views & images.
  private var isBatchUpdating = false

  /// Updates the collection view snapshot based upon the current view models.
  private func updateSnapshot() {
    assert(Thread.isMainThread)
    guard !isBatchUpdating else { return }
    var snapshot = NSDiffableDataSourceSnapshot<Int, SearchResultsViewModel>()
    snapshot.appendSections([0])
    snapshot.appendItems(searchResultsViewModels.removingDuplicates())
    dataSource.apply(snapshot, animatingDifferences: true)
  }

  /// Flag indicating if the barcode scanner UI is currently on the screen.
  private var isShowingBarcodeScanner = false

  /// Hides the search results so you can see the editing surface.
  private func hideSearchResults() {
    Logger.bookSearch.info("Hiding search results")
    UIView.animate(withDuration: 0.2) { [collectionView, barcodeScannerViewController] in
      collectionView.alpha = 0
      barcodeScannerViewController.view.alpha = 0
    } completion: { [collectionView] success in
      Logger.bookSearch.debug("Hiding done. Success = \(success), alpha = \(collectionView.alpha)")
    }
  }

  /// Shows the search results, obscuring the editing surface.
  private func showSearchResults() {
    Logger.bookSearch.info("Showing search results")
    UIView.animate(withDuration: 0.2) { [collectionView, barcodeScannerViewController] in
      collectionView.alpha = 1
      barcodeScannerViewController.view.alpha = 1
    }
  }

  /// Start showing the barcode scanner UI.
  private func startScanning() async {
    guard !isShowingBarcodeScanner else { return }
    do {
      guard try await barcodeScannerViewController.startScanning() else {
        Logger.bookSearch.info("Cannot start scanning: No permission")
        return
      }
      isShowingBarcodeScanner = true
      UIView.animate(withDuration: 0.2) {
        self.updateBarcodeScannerConstraints(shouldShowBarcodeScanner: true)
        self.view.layoutIfNeeded()
      }
    } catch {
      Logger.bookSearch.error("Unexpected error scanning barcodes: \(error)")
    }
  }

  /// Stop showing the barcode scanner UI.
  private func stopScanning() {
    guard isShowingBarcodeScanner else { return }
    isShowingBarcodeScanner = false
    UIView.animate(withDuration: 0.2) {
      self.updateBarcodeScannerConstraints(shouldShowBarcodeScanner: false)
      self.view.layoutIfNeeded()
    }
  }

  private func updateBarcodeScannerConstraints(shouldShowBarcodeScanner: Bool) {
    let newHeight = shouldShowBarcodeScanner ? 200 : 0
    barcodeScannerViewController.view.snp.remakeConstraints { make in
      make.top.left.right.equalTo(view.safeAreaLayoutGuide)
      make.height.equalTo(newHeight)
    }
  }

  private lazy var skipButton = UIBarButtonItem(title: "Skip", primaryAction: UIAction { [weak self] _ in
    guard let self = self else { return }
    if self.model.isValid {
      self.delegate?.bookSearchViewController(self, didSelect: self.model.book, coverImage: self.model.coverImage)
    } else {
      self.delegate?.bookSearchViewControllerDidSkip(self)
    }
  })

  private lazy var nextButton = UIBarButtonItem(title: "Next", primaryAction: UIAction { [weak self] _ in
    guard let self = self else { return }
    if self.model.isValid {
      self.delegate?.bookSearchViewController(self, didSelect: self.model.book, coverImage: self.model.coverImage)
    } else {
      Logger.bookSearch.error("Tapped Next on an invalid model. How?")
    }
  })

  override public func viewDidLoad() {
    super.viewDidLoad()
    addChild(barcodeScannerViewController)
    barcodeScannerViewController.didMove(toParent: self)
    let hostingViewController = UIHostingController(rootView: BookEditView(model: model))
    addChild(hostingViewController)
    hostingViewController.didMove(toParent: self)

    let subviews: [UIView] = [
      hostingViewController.view,
      barcodeScannerViewController.view,
      collectionView,
      activityView,
    ]
    for subview in subviews {
      view.addSubview(subview)
    }
    updateBarcodeScannerConstraints(shouldShowBarcodeScanner: false)
    hostingViewController.view.snp.makeConstraints { make in
      make.edges.equalTo(view.safeAreaLayoutGuide)
    }
    collectionView.snp.makeConstraints { make in
      make.top.equalTo(barcodeScannerViewController.view.snp.bottom)
      make.left.right.bottom.equalTo(view.safeAreaLayoutGuide)
    }
    activityView.snp.makeConstraints { make in
      make.center.equalToSuperview()
    }
    collectionView.alpha = 0
    barcodeScannerViewController.view.alpha = 0

    view.tintColor = .grailTint
    view.backgroundColor = .grailBackground
    let cancelButton = UIBarButtonItem(systemItem: .cancel)
    cancelButton.primaryAction = UIAction { [weak self] _ in
      guard let self = self else { return }
      self.delegate?.bookSearchViewControllerDidCancel(self)
    }
    navigationItem.leftBarButtonItem = cancelButton

    navigationItem.searchController = searchController
    monitorModelAndUpdateRightBarButtonItem()
  }

  private var modelSubscription: AnyCancellable?

  /// Set to `true` to trigger an update of the right bar button item at the next tick of the run loop.
  private var rightBarButtonItemNeedsUpdate = true

  /// Sets up the code needed for keeping the right bar button item up-to-date.
  ///
  /// * Sets up the run loop observer that monitors `rightBarButtonItemNeedsUpdate`
  /// * Monitors `model` and sets `rightBarButtonItemNeedsUpdate` to `true` when the model will change
  private func monitorModelAndUpdateRightBarButtonItem() {
    let needsPerformUpdatesObserver = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.beforeWaiting.rawValue, true, 0) { [weak self] _, _ in
      self?.updateRightBarButtonItemIfNeeded()
    }
    CFRunLoopAddObserver(CFRunLoopGetMain(), needsPerformUpdatesObserver, CFRunLoopMode.commonModes)
    modelSubscription = model.objectWillChange.sink { [weak self] _ in
      Logger.bookSearch.debug("Setting nextButtonNeedsUpdate to true. Model valid? \(self?.model.isValid ?? false)")
      self?.rightBarButtonItemNeedsUpdate = true
    }
    updateRightBarButtonItemIfNeeded()
  }

  /// If `rightBarButtonItemNeedsUpdate` is true, configures `navigationItem.rightBarButtonItem` to the proper value given the current state
  /// of the view controller.
  private func updateRightBarButtonItemIfNeeded() {
    guard rightBarButtonItemNeedsUpdate else { return }
    rightBarButtonItemNeedsUpdate = false
    Logger.bookSearch.debug("Processing nextButtonNeedsUpdate to true. Model valid? \(model.isValid)")
    if model.isValid {
      navigationItem.rightBarButtonItem = nextButton
      nextButton.isEnabled = true
    } else {
      if showSkipButton {
        navigationItem.rightBarButtonItem = skipButton
      } else {
        navigationItem.rightBarButtonItem = nextButton
        nextButton.isEnabled = false
      }
    }
  }
}

extension BookEditDetailsViewController: UICollectionViewDelegate {
  public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    Logger.bookSearch.debug("Selected item at \(indexPath)")
    guard let viewModel = dataSource.itemIdentifier(for: indexPath) else { return }
    model.book = AugmentedBook(viewModel.book)
    model.coverImage = viewModel.coverImage
    hideSearchResults()
  }
}

extension BookEditDetailsViewController: UISearchControllerDelegate {
  public func didDismissSearchController(_ searchController: UISearchController) {
    Logger.bookSearch.debug("Did dismiss search controller")
  }
}

// MARK: - UISearchBarDelegate

extension BookEditDetailsViewController: UISearchBarDelegate {
  public func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
    guard let searchTerm = searchBar.text, let apiKey = ApiKey.googleBooks else { return }
    Task {
      do {
        try await searchGoogleBooks(for: searchTerm, apiKey: apiKey)
      } catch {
        Logger.shared.error("Unexpected error searching Google Books: \(error)")
      }
    }
  }

  public func searchBarBookmarkButtonClicked(_ searchBar: UISearchBar) {
    if isShowingBarcodeScanner {
      stopScanning()
    } else {
      showSearchResults()
      Task {
        await startScanning()
      }
    }
  }

  @MainActor
  private func searchGoogleBooks(for searchTerm: String, apiKey: String) async throws {
    // TODO: Xcode 13 Beta 3 doesn't recognize "defer" blocks as being in the global actor
    do {
      activityView.startAnimating()
      let response = try await GoogleBooks.search(for: searchTerm, apiKey: apiKey)
      activityView.stopAnimating()
      let viewModels = response.items.compactMap { SearchResultsViewModel($0) }
      updateViewModels(viewModels)
      showSearchResults()
      searchController.isActive = false
    } catch {
      activityView.stopAnimating()
      throw error
    }
  }
}

// MARK: - BarcodeScannerViewControllerDelegate

extension BookEditDetailsViewController: BarcodeScannerViewControllerDelegate {
  public func barcodeScannerViewController(_ viewController: BarcodeScannerViewController, didUpdateRecognizedBarcodes barcodes: Set<String>) {
    Logger.bookSearch.info("Found barcodes: \(barcodes)")
    if let barcode = barcodes.first {
      searchController.searchBar.text = barcode
      stopScanning()
      searchBarTextDidEndEditing(searchController.searchBar)
    }
  }
}

private struct SearchResultsViewModel: Hashable, Identifiable {
  var id = UUID()
  var book: Book
  var coverImage: UIImage?
  var coverImageURL: URL?

  init?(_ item: GoogleBooks.Item) {
    guard let book = Book(item) else { return nil }
    self.book = book
    self.coverImage = nil
    if let urlString = item.volumeInfo.imageLinks?.smallThumbnail ?? item.volumeInfo.imageLinks?.thumbnail {
      self.coverImageURL = URL(string: urlString)
    }
  }
}

private extension Array where Element: Hashable {
  func removingDuplicates() -> Self {
    var alreadySeen: Set<Element> = []
    return filter {
      if alreadySeen.contains($0) { return false }
      alreadySeen.insert($0)
      return true
    }
  }
}
