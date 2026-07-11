// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import ImageIO
import SwiftUI
import WidgetKit

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
  case widgetLarge
}

public struct QuoteCardView: View {
  private let model: QuoteDisplayModel
  private let mode: QuoteCardDisplayMode
  private let accessory: AnyView?

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @ScaledMetric(relativeTo: .headline) private var widgetQuoteFontSize = 17
  @ScaledMetric(relativeTo: .headline) private var widgetAttributionFontSize = 12
  @ScaledMetric(relativeTo: .title3) private var largeWidgetQuoteFontSize = 20

  public init(
    model: QuoteDisplayModel,
    mode: QuoteCardDisplayMode = .list,
    accessory: AnyView? = nil
  ) {
    self.model = model
    self.mode = mode
    self.accessory = accessory
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
    case .widgetLarge:
      largeWidgetBody
    }
  }

  private var listBody: some View {
    HStack(alignment: .top, spacing: 8) {
      if let image = thumbnailImage(maxPixelSize: 320) {
        imageView(image)
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
          .aspectRatio(contentMode: .fit)
          .frame(width: 140)
          .accessibilityHidden(true)
      }

      textStack(quoteLineLimit: nil, attributionLineLimit: nil)
    }
    .padding(8)
  }

  private var compactWidgetBody: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(model.attributedQuoteText)
        .font(.system(size: widgetQuoteFontSize, weight: .semibold, design: .serif))
        .lineLimit(5)
        .minimumScaleFactor(0.85)
        .fixedSize(horizontal: false, vertical: true)

      HStack(alignment: .firstTextBaseline, spacing: 8) {
        if !model.attributionText.isEmpty {
          Text(model.attributedAttributionText)
            .font(.system(size: widgetAttributionFontSize))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
        }

        Spacer(minLength: 0)

        accessory
      }

      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var mediumWidgetBody: some View {
    HStack(alignment: .top, spacing: 12) {
      if let image = thumbnailImage(maxPixelSize: 160) {
        imageView(image)
          .aspectRatio(contentMode: .fit)
          .frame(width: 88)
          .frame(maxHeight: .infinity, alignment: .top)
          .accessibilityHidden(true)
      }

      mediumWidgetTextStack
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var mediumWidgetTextStack: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(model.attributedQuoteText)
        .font(.system(size: widgetQuoteFontSize, weight: .semibold, design: .serif))
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 6 : 5)
        .minimumScaleFactor(0.85)
        .fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: 4)

      HStack(alignment: .firstTextBaseline, spacing: 8) {
        if !model.attributionText.isEmpty {
          Text(model.attributedAttributionText)
            .font(.system(size: widgetAttributionFontSize))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
        }

        Spacer(minLength: 0)

        accessory
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var largeWidgetBody: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(alignment: .bottom, spacing: 14) {
        if let image = thumbnailImage(maxPixelSize: 240) {
          imageView(image)
            .aspectRatio(contentMode: .fit)
            .frame(width: 96, height: 144)
            .accessibilityHidden(true)
        }

        if !model.attributionText.isEmpty {
          Text(model.attributedAttributionText)
            .font(.system(size: widgetAttributionFontSize))
            .foregroundStyle(.secondary)
            .lineLimit(3)
        }

        Spacer(minLength: 0)

        accessory
      }

      Text(model.attributedQuoteText)
        .font(.system(size: largeWidgetQuoteFontSize, weight: .semibold, design: .serif))
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 12 : 9)
        .minimumScaleFactor(0.9)
        .fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: 0)
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

  @ViewBuilder
  private func imageView(_ image: PlatformImage) -> some View {
    #if canImport(UIKit)
      if #available(iOS 18.0, *) {
        Image(uiImage: image)
          .resizable()
          .widgetAccentedRenderingMode(.fullColor)
      } else {
        Image(uiImage: image)
          .resizable()
      }
    #else
      if #available(macOS 15.0, *) {
        Image(nsImage: image)
          .resizable()
          .widgetAccentedRenderingMode(.fullColor)
      } else {
        Image(nsImage: image)
          .resizable()
      }
    #endif
  }

  private func thumbnailImage(maxPixelSize: CGFloat) -> PlatformImage? {
    guard shouldShowCoverImage else { return nil }
    return model.thumbnailImage?.image(maxPixelSize: maxPixelSize)
  }

  private var shouldShowCoverImage: Bool {
    switch mode {
    case .list, .share:
      true
    case .widgetMedium, .widgetLarge:
      !dynamicTypeSize.isAccessibilitySize
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
