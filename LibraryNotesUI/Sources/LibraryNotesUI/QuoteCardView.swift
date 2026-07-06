// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import ImageIO
import SwiftUI

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

public enum QuoteCardDisplayMode: Sendable {
  case list
  case share
  case widgetSmall
  case widgetMedium
}

public struct QuoteCardView: View {
  private let model: QuoteDisplayModel
  private let mode: QuoteCardDisplayMode

  public init(model: QuoteDisplayModel, mode: QuoteCardDisplayMode = .list) {
    self.model = model
    self.mode = mode
  }

  public var body: some View {
    switch mode {
    case .list:
      listBody
    case .share:
      shareBody
    case .widgetSmall:
      compactWidgetBody
    case .widgetMedium:
      mediumWidgetBody
    }
  }

  private var listBody: some View {
    HStack(alignment: .top, spacing: 8) {
      if let image = thumbnailImage(maxPixelSize: 320) {
        imageView(image)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(maxWidth: 160, alignment: .top)
          .containerRelativeFrame(.horizontal, count: 4, spacing: 8)
          .accessibilityHidden(true)
      }

      textStack(quoteLineLimit: nil, attributionLineLimit: nil)
    }
    .padding(8)
  }

  private var shareBody: some View {
    HStack(alignment: .top, spacing: 8) {
      if let image = thumbnailImage(maxPixelSize: 320) {
        imageView(image)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 140)
          .accessibilityHidden(true)
      }

      textStack(quoteLineLimit: nil, attributionLineLimit: nil)
    }
    .padding(8)
  }

  private var compactWidgetBody: some View {
    textStack(quoteLineLimit: 5, attributionLineLimit: 2)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var mediumWidgetBody: some View {
    HStack(alignment: .top, spacing: 8) {
      if let image = thumbnailImage(maxPixelSize: 160) {
        imageView(image)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 58)
          .accessibilityHidden(true)
      }

      textStack(quoteLineLimit: 4, attributionLineLimit: 2)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private func textStack(quoteLineLimit: Int?, attributionLineLimit: Int?) -> some View {
    VStack(alignment: .leading, spacing: mode == .list ? 16 : 8) {
      Text(model.attributedQuoteText)
        .font(.system(mode == .list ? .body : .headline, design: .serif))
        .lineLimit(quoteLineLimit)
        .minimumScaleFactor(mode == .list ? 1 : 0.72)
        .fixedSize(horizontal: false, vertical: true)

      if !model.attributionText.isEmpty {
        Text(model.attributedAttributionText)
          .font(.caption)
          .foregroundStyle(.primary)
          .lineLimit(attributionLineLimit)
          .minimumScaleFactor(0.75)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func imageView(_ image: PlatformImage) -> Image {
    #if canImport(UIKit)
      Image(uiImage: image)
    #else
      Image(nsImage: image)
    #endif
  }

  private func thumbnailImage(maxPixelSize: CGFloat) -> PlatformImage? {
    guard shouldShowCoverImage else { return nil }
    return model.thumbnailImage?.image(maxPixelSize: maxPixelSize)
  }

  private var shouldShowCoverImage: Bool {
    switch mode {
    case .list, .share, .widgetMedium:
      true
    case .widgetSmall:
      false
    }
  }
}

private extension Data {
  func image(maxPixelSize: CGFloat) -> PlatformImage? {
    guard let imageSource = CGImageSourceCreateWithData(self as CFData, nil) else {
      return nil
    }
    let options: [NSString: NSObject] = [
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize as NSObject,
      kCGImageSourceCreateThumbnailFromImageAlways: true as NSObject,
      kCGImageSourceCreateThumbnailWithTransform: true as NSObject,
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary?) else {
      return nil
    }
    #if canImport(UIKit)
      return UIImage(cgImage: image)
    #else
      return NSImage(cgImage: image, size: .zero)
    #endif
  }
}

#if canImport(UIKit)
  private typealias PlatformImage = UIImage
#elseif canImport(AppKit)
  private typealias PlatformImage = NSImage
#endif

#Preview {
  QuoteCardView(
    model: QuoteDisplayModel(
      noteId: "preview",
      key: "quote",
      quoteText: "The most important aspect of both examples is that a definite choice was made.",
      attributionText: "Thinking Fast and Slow, 80"
    )
  )
  .padding()
  .background(Color.grailBackground)
}
