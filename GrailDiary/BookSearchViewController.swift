// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import Combine
import Logging
import UIKit

private extension Logger {
  static let bookSearch: Logger = {
    var bookSearch = Logger(label: "org.brians-brain.BookSearch")
    bookSearch.logLevel = .debug
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
  func bookSearchViewController(_ viewController: BookSearchViewController, didSelect book: Book, coverImage: UIImage?)

  /// The person canceled without selecting a book.
  /// (Note this is not guaranteed to be called with the pull-down presentation style)
  func bookSearchViewControllerDidCancel(_ viewController: BookSearchViewController)

  /// The person skipped adding book details to a new note.
  func bookSearchViewControllerDidSkip(_ viewController: BookSearchViewController)
}

/// Searches Google for information about a book.
public final class BookSearchViewController: UIViewController {
  public init(apiKey: String, showSkipButton: Bool) {
    self.apiKey = apiKey
    self.showSkipButton = showSkipButton
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
    searchController.showsSearchResultsController = true
    searchController.searchBar.searchTextField.clearButtonMode = .whileEditing
    searchController.obscuresBackgroundDuringPresentation = false
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

  override public func viewDidLoad() {
    super.viewDidLoad()
    [
      collectionView,
      activityView,
    ].forEach(view.addSubview)
    collectionView.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
    activityView.snp.makeConstraints { make in
      make.center.equalToSuperview()
    }
    view.tintColor = .grailTint
    view.backgroundColor = .grailBackground
    let cancelButton = UIBarButtonItem(systemItem: .cancel)
    cancelButton.primaryAction = UIAction { [weak self] _ in
      guard let self = self else { return }
      self.delegate?.bookSearchViewControllerDidCancel(self)
    }
    navigationItem.leftBarButtonItem = cancelButton

    if showSkipButton {
      let skipButton = UIBarButtonItem(title: "Next", primaryAction: UIAction { [weak self] _ in
        guard let self = self else { return }
        self.delegate?.bookSearchViewControllerDidSkip(self)
      })
      navigationItem.rightBarButtonItem = skipButton
    }
    navigationItem.searchController = searchController
  }
}

extension BookSearchViewController: UICollectionViewDelegate {
  public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    guard let viewModel = dataSource.itemIdentifier(for: indexPath) else { return }
    delegate?.bookSearchViewController(self, didSelect: viewModel.book, coverImage: viewModel.coverImage)
  }
}

// MARK: - Private

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

  @MainActor
  private func searchGoogleBooks(for searchTerm: String, apiKey: String) async throws {
    // TODO: Xcode 13 Beta 3 doesn't recognize "defer" blocks as being in the global actor
    do {
      activityView.startAnimating()
      let response = try await GoogleBooks.search(for: searchTerm, apiKey: apiKey)
      activityView.stopAnimating()
      let viewModels = response.items.compactMap { ViewModel($0) }
      updateViewModels(viewModels)
    } catch {
      activityView.stopAnimating()
      throw error
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
