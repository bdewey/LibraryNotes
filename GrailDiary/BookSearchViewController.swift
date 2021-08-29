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

private struct ViewModel: Hashable, Identifiable {
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

public protocol BookSearchViewControllerDelegate: AnyObject {
  /// The person selected a book.
  func bookSearchViewController(_ viewController: BookSearchViewController, didSelect book: AugmentedBook, coverImage: UIImage?)

  /// The person canceled without selecting a book.
  /// (Note this is not guaranteed to be called with the pull-down presentation style)
  func bookSearchViewControllerDidCancel(_ viewController: BookSearchViewController)

  /// The person skipped adding book details to a new note.
  func bookSearchViewControllerDidSkip(_ viewController: BookSearchViewController)
}

public extension AugmentedBook {
  /// A blank book.
  static let blank = AugmentedBook(title: "", authors: [])
}

@MainActor
public final class BookSearchViewController: UIViewController {
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

  public weak var delegate: BookSearchViewControllerDelegate?
  private let apiKey: String
  private let showSkipButton: Bool

  public enum Error: Swift.Error {
    case invalidServerResponse
  }

  private lazy var searchController: UISearchController = {
    let searchController = UISearchController(searchResultsController: nil)
    searchController.searchBar.delegate = self
    searchController.searchBar.showsBookmarkButton = CaptureSessionManager.defaultVideoDevice != nil
    searchController.searchBar.setImage(UIImage(systemName: "barcode.viewfinder"), for: .bookmark, state: .normal)
    searchController.showsSearchResultsController = true
    searchController.searchBar.searchTextField.clearButtonMode = .whileEditing
    searchController.obscuresBackgroundDuringPresentation = true
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

  private lazy var dataSource: UICollectionViewDiffableDataSource<Int, ViewModel> = {
    let bookRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, ViewModel> { cell, _, viewModel in
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

    return UICollectionViewDiffableDataSource<Int, ViewModel>(collectionView: collectionView) { collectionView, indexPath, book in
      collectionView.dequeueConfiguredReusableCell(using: bookRegistration, for: indexPath, item: book)
    }
  }()

  private let imageCache = ImageCache()
  private var viewModels = [ViewModel]()
  private var model = BookEditViewModel(book: AugmentedBook(title: "", authors: []), coverImage: nil)
  private lazy var decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()

  private let activityView = UIActivityIndicatorView(style: .large)

  private func updateViewModels(_ viewModels: [ViewModel]) {
    assert(Thread.isMainThread)
    isBatchUpdating = true
    self.viewModels = viewModels
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
    guard let index = viewModels.firstIndex(where: { $0.id == key }) else { return }
    viewModels[index].coverImage = image
    updateSnapshot()
  }

  private var isBatchUpdating = false

  private func updateSnapshot() {
    assert(Thread.isMainThread)
    guard !isBatchUpdating else { return }
    var snapshot = NSDiffableDataSourceSnapshot<Int, ViewModel>()
    snapshot.appendSections([0])
    snapshot.appendItems(viewModels.removingDuplicates())
    dataSource.apply(snapshot, animatingDifferences: true)
  }

  private var isShowingBarcodeScanner = false

  private func hideSearchResults() {
    Logger.bookSearch.info("Hiding search results")
    UIView.animate(withDuration: 0.2) { [collectionView, barcodeScannerViewController] in
      collectionView.alpha = 0
      barcodeScannerViewController.view.alpha = 0
    } completion: { [collectionView] success in
      Logger.bookSearch.debug("Hiding done. Success = \(success), alpha = \(collectionView.alpha)")
    }
  }

  private func showSearchResults() {
    Logger.bookSearch.info("Showing search results")
    UIView.animate(withDuration: 0.2) { [collectionView, barcodeScannerViewController] in
      collectionView.alpha = 1
      barcodeScannerViewController.view.alpha = 1
    }
  }

  @MainActor
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

    let skipButton = UIBarButtonItem(title: "Next", primaryAction: UIAction { [weak self] _ in
      guard let self = self else { return }
      if self.model.isValid {
        self.delegate?.bookSearchViewController(self, didSelect: self.model.book, coverImage: self.model.coverImage)
      } else {
        self.delegate?.bookSearchViewControllerDidSkip(self)
      }
    })
    navigationItem.rightBarButtonItem = skipButton
    navigationItem.searchController = searchController
    let needsPerformUpdatesObserver = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.beforeWaiting.rawValue, true, 0) { [weak self] _, _ in
      self?.updateRightBarButtonItemIfNeeded()
    }
    CFRunLoopAddObserver(CFRunLoopGetMain(), needsPerformUpdatesObserver, CFRunLoopMode.commonModes)
    modelSubscription = model.objectWillChange.sink { [weak self] _ in
      Logger.bookSearch.debug("Setting nextButtonNeedsUpdate to true. Model valid? \(self?.model.isValid ?? false)")
      self?.nextButtonNeedsUpdate = true
    }
    updateRightBarButtonItemIfNeeded()
  }

  private var modelSubscription: AnyCancellable?
  private var nextButtonNeedsUpdate = true

  private func updateRightBarButtonItemIfNeeded() {
    guard nextButtonNeedsUpdate else { return }
    nextButtonNeedsUpdate = false
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

extension BookSearchViewController: UICollectionViewDelegate {
  public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    Logger.bookSearch.debug("Selected item at \(indexPath)")
    guard let viewModel = dataSource.itemIdentifier(for: indexPath) else { return }
    model.book = AugmentedBook(viewModel.book)
    model.coverImage = viewModel.coverImage
    hideSearchResults()
  }
}

extension BookSearchViewController: UISearchControllerDelegate {
  public func didDismissSearchController(_ searchController: UISearchController) {
    Logger.bookSearch.debug("Did dismiss seaarch controller")
  }
}

// MARK: - UISearchBarDelegate

extension BookSearchViewController: UISearchBarDelegate {
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
      let viewModels = response.items.compactMap { ViewModel($0) }
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

extension BookSearchViewController: BarcodeScannerViewControllerDelegate {
  public func barcodeScannerViewController(_ viewController: BarcodeScannerViewController, didUpdateRecognizedBarcodes barcodes: Set<String>) {
    Logger.bookSearch.info("Found barcodes: \(barcodes)")
    if let barcode = barcodes.first {
      searchController.searchBar.text = barcode
      stopScanning()
      searchBarTextDidEndEditing(searchController.searchBar)
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
