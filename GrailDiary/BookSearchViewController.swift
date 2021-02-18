// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Combine
import Logging
import UIKit

public struct Book: Hashable {
  var id: String
  var title: String
  var authors: [String]
  var publishedDate: String?
  var coverImage: UIImage?
  var coverImageURL: URL?

  var markdownTitle: String {
    var title = "_\(self.title)_"
    if !authors.isEmpty {
      let authors = self.authors.joined(separator: ", ")
      title += ": \(authors)"
    }
    if let publishedDate = publishedDate {
      title += " (\(publishedDate.prefix(4)))"
    }
    return title
  }
}

public protocol BookSearchViewControllerDelegate: AnyObject {
  /// The person selected a book.
  func bookSearchViewController(_ viewController: BookSearchViewController, didSelect book: Book)

  /// The person canceled without selecting a book.
  /// (Note this is not guaranteed to be called with the pull-down presentation style)
  func bookSearchViewControllerDidCancel(_ viewController: BookSearchViewController)
}

/// Searches Google for information about a book.
public final class BookSearchViewController: UIViewController {
  public init(apiKey: String) {
    self.apiKey = apiKey
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public weak var delegate: BookSearchViewControllerDelegate?
  private let apiKey: String

  public enum Error: Swift.Error {
    case invalidServerResponse
  }

  private lazy var searchController: UISearchController = {
    let searchController = UISearchController(searchResultsController: nil)
    searchController.searchResultsUpdater = self
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
    return collectionView
  }()

  private lazy var dataSource: UICollectionViewDiffableDataSource<Int, Book> = {
    let bookRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Book> { cell, _, book in
      var configuration = cell.defaultContentConfiguration()
      if let publishedDate = book.publishedDate {
        let year = publishedDate.prefix(4)
        configuration.text = "\(book.title) (\(year))"
      } else {
        configuration.text = book.title
      }
      configuration.textProperties.color = .label
      configuration.secondaryText = book.authors.joined(separator: ", ")
      configuration.secondaryTextProperties.color = .secondaryLabel
      configuration.image = book.coverImage
      var backgroundConfiguration = UIBackgroundConfiguration.listPlainCell()
      backgroundConfiguration.backgroundColor = .grailBackground

      cell.contentConfiguration = configuration
      cell.backgroundConfiguration = backgroundConfiguration
    }

    return UICollectionViewDiffableDataSource<Int, Book>(collectionView: collectionView) { collectionView, indexPath, book in
      collectionView.dequeueConfiguredReusableCell(using: bookRegistration, for: indexPath, item: book)
    }
  }()

  private let currentSearchTerm = CurrentValueSubject<String, Never>("")
  private var currentSearch: AnyCancellable?
  private let imageCache = ImageCache()
  private var viewModels = [Book]()
  private lazy var decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()

  private func updateViewModels(_ viewModels: [Book]) {
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

  private func setViewModelImage(_ image: UIImage, key: String) {
    assert(Thread.isMainThread)
    guard let index = viewModels.firstIndex(where: { $0.id == key }) else { return }
    viewModels[index].coverImage = image
    updateSnapshot()
  }

  private var isBatchUpdating = false

  private func updateSnapshot() {
    assert(Thread.isMainThread)
    guard !isBatchUpdating else { return }
    var snapshot = NSDiffableDataSourceSnapshot<Int, Book>()
    snapshot.appendSections([0])
    snapshot.appendItems(viewModels.removingDuplicates())
    dataSource.apply(snapshot, animatingDifferences: true)
  }

  override public func loadView() {
    view = collectionView
  }

  override public func viewDidLoad() {
    super.viewDidLoad()
    view.tintColor = .grailTint
    view.backgroundColor = .grailBackground
    let cancelButton = UIBarButtonItem(systemItem: .cancel)
    cancelButton.primaryAction = UIAction { [weak self] _ in
      guard let self = self else { return }
      self.delegate?.bookSearchViewControllerDidCancel(self)
    }
    navigationItem.leftBarButtonItem = cancelButton
    navigationItem.searchController = searchController

    currentSearch = currentSearchTerm
      .filter { !$0.isEmpty }
      .debounce(for: 0.5, scheduler: RunLoop.main)
      .map { [apiKey] queryValue -> URL in
        var urlComponents = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")!
        urlComponents.queryItems = [
          URLQueryItem(name: "q", value: queryValue),
          URLQueryItem(name: "key", value: apiKey),
        ]
        return urlComponents.url!
      }
      .flatMap { url -> URLSession.DataTaskPublisher in
        Logger.shared.debug("Querying: \(url)")
        return URLSession.shared.dataTaskPublisher(for: url)
      }
      .tryMap { data, response in
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
          Logger.shared.error("Unexpected response")
          throw Error.invalidServerResponse
        }
        Logger.shared.debug("Got valid data")
        return data
      }
      .decode(type: GoogleBooksResponse.self, decoder: decoder)
      .sink { completion in
        switch completion {
        case .failure(let error):
          Logger.shared.error("Unexpected error searching for term': \(error)")
        case .finished:
          Logger.shared.info("Search for finished")
        }
      } receiveValue: { [weak self] data in
        DispatchQueue.main.async {
          self?.updateViewModels(data.items.map { Book($0) })
        }
      }
  }

  override public func viewDidAppear(_ animated: Bool) {
    searchController.isActive = true
  }
}

extension BookSearchViewController: UICollectionViewDelegate {
  public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    guard let book = dataSource.itemIdentifier(for: indexPath) else { return }
    delegate?.bookSearchViewController(self, didSelect: book)
  }
}

// MARK: - Private

private extension BookSearchViewController {
  struct GoogleBooksResponse: Codable {
    var totalItems: Int
    var items: [GoogleBooksItem]
  }

  struct GoogleBooksItem: Codable {
    var id: String
    var volumeInfo: VolumeInfo
  }

  struct VolumeInfo: Codable {
    var title: String
    var subtitle: String?
    var authors: [String]?
    var publishedDate: String?
    var imageLinks: ImageLink?
  }

  struct ImageLink: Codable {
    var smallThumbnail: String?
    var thumbnail: String?
  }
}

private extension Book {
  init(_ item: BookSearchViewController.GoogleBooksItem) {
    self.id = item.id
    self.title = item.volumeInfo.title
    self.authors = item.volumeInfo.authors ?? []
    self.publishedDate = item.volumeInfo.publishedDate
    self.coverImage = nil
    if let urlString = item.volumeInfo.imageLinks?.smallThumbnail ?? item.volumeInfo.imageLinks?.thumbnail {
      self.coverImageURL = URL(string: urlString)
    }
  }
}

extension BookSearchViewController: UISearchResultsUpdating {
  public func updateSearchResults(for searchController: UISearchController) {
    currentSearchTerm.send(searchController.searchBar.text ?? "")
  }
}

extension BookSearchViewController: UISearchBarDelegate {}

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
