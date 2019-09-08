// Copyright © 2019 Brian's Brain. All rights reserved.

import CocoaLumberjack
import SnapKit
import SwiftUI
import UIKit

/// Displays image search results in a UICollectionView.
struct ImageSearchResultsView: UIViewRepresentable {
  let searchResults: ImageSearchRequest.SearchResults?
  var onSelectedImage: (EncodedImage) -> Void = { _ in }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeUIView(context: UIViewRepresentableContext<ImageSearchResultsView>) -> UICollectionView {
    let layout = UICollectionViewFlowLayout()
    layout.scrollDirection = .horizontal
    layout.itemSize = CGSize(width: 200, height: 200)
    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    collectionView.register(ImageCell.self, forCellWithReuseIdentifier: ReuseIdentifiers.imageCell)
    collectionView.dataSource = context.coordinator
    collectionView.delegate = context.coordinator
    collectionView.backgroundColor = .systemBackground
    return collectionView
  }

  func updateUIView(
    _ uiView: UICollectionView,
    context: UIViewRepresentableContext<ImageSearchResultsView>
  ) {
    if context.coordinator.searchResults != searchResults {
      context.coordinator.searchResults = searchResults
      uiView.reloadData()
    }
  }

  final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
    init(_ view: ImageSearchResultsView) {
      self.view = view
    }

    let view: ImageSearchResultsView
    var searchResults: ImageSearchRequest.SearchResults?

    func numberOfSections(in collectionView: UICollectionView) -> Int {
      return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
      guard let searchResults = searchResults else { return 0 }
      return searchResults.images.value.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: ReuseIdentifiers.imageCell,
        for: indexPath
      ) as! ImageCell // swiftlint:disable:this force_cast
      cell.image = searchResults?.images.value[indexPath.item]
      return cell
    }

    /// Download the full image and call the completion routine.
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
      guard
        let cell = collectionView.cellForItem(at: indexPath) as? ImageCell,
        let encodedImage = cell.encodedImage
      else {
        return
      }
      view.onSelectedImage(encodedImage)
    }
  }

  private enum ReuseIdentifiers {
    static let imageCell = "ImageCell"
  }

  /// Shows an image. Will initiate the download of the thumbnail image.
  private final class ImageCell: UICollectionViewCell {
    override init(frame: CGRect) {
      super.init(frame: frame)
      contentView.addSubview(imageView)
      imageView.snp.makeConstraints { make in
        make.edges.equalToSuperview()
      }
    }

    var image: ImageSearchRequest.Image? {
      didSet {
        if let image = image, let rgb = UInt32(image.accentColor, radix: 16) {
          encodedImage = nil
          imageView.backgroundColor = UIColor(rgb: rgb)
          downloadAndDisplayImage(image)
        } else {
          imageView.image = nil
        }
      }
    }

    private lazy var imageView = UIImageView(frame: .zero)
    var encodedImage: EncodedImage?

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    /// The image to show in this cell.
    private func downloadAndDisplayImage(_ image: ImageSearchRequest.Image) {
      guard let thumbnailURL = URL(string: image.thumbnailUrl) else {
        return
      }
      let task = URLSession.shared.dataTask(with: thumbnailURL) { [weak self] data, _, error in
        if let error = error {
          DDLogError("Error loading image \(thumbnailURL): \(error)")
          return
        }
        guard self?.image == image, let data = data else {
          DDLogError("No data returned for \(thumbnailURL)")
          return
        }
        self?.encodedImage = EncodedImage(
          data: data,
          encoding: image.encodingFormat, // TODO: This might be wrong.
          width: image.thumbnail.width,
          height: image.thumbnail.height
        )
        let decodedImage = UIImage(data: data)
        DispatchQueue.main.async {
          self?.imageView.image = decodedImage
        }
      }
      task.resume()
    }
  }
}

extension UIColor {
  public convenience init(rgb: UInt32, alpha: CGFloat = 1.0) {
    self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
              green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
              blue: CGFloat(rgb & 0xFF) / 255.0,
              alpha: alpha)
  }
}
