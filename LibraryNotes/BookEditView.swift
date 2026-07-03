// Copyright (c) 2018-2025  Brian Dewey. Covered by the Apache 2.0 license.

import LibraryNotesCore
import BookKit
import SwiftUI

/// Holds a book and its cover image so it can be edited.
///
/// For convenience with `TextField` views, this model provides a methods that create `String` bindings for non-string `AugmentedBook` fields.
final class BookEditViewModel: ObservableObject {
  @Published var book: AugmentedBook
  @Published var coverImage: UIImage?

  init(book: AugmentedBook, coverImage: UIImage?) {
    self.book = book
    self.coverImage = coverImage
  }

  /// True if this model contains a valid book.
  ///
  /// At the moment the only "invalid" book is one without a title.
  var isValid: Bool {
    !book.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  subscript(asString keyPath: WritableKeyPath<AugmentedBook, [String]>) -> String {
    get {
      book[keyPath: keyPath].joined(separator: ", ")
    }
    set {
      book[keyPath: keyPath] = newValue.split(separator: ",")
        .map(String.init)
        .map { $0.trimmingCharacters(in: .whitespaces) }
    }
  }

  subscript(asString keyPath: WritableKeyPath<AugmentedBook, [String]?>) -> String {
    get {
      book[keyPath: keyPath]?.joined(separator: ", ") ?? ""
    }
    set {
      book[keyPath: keyPath] = newValue.split(separator: ",")
        .map(String.init)
        .map { $0.trimmingCharacters(in: .whitespaces) }
    }
  }

  subscript(asString keyPath: WritableKeyPath<AugmentedBook, String?>) -> String {
    get {
      book[keyPath: keyPath] ?? ""
    }
    set {
      book[keyPath: keyPath] = newValue
    }
  }

  subscript(asString keyPath: WritableKeyPath<AugmentedBook, Int?>) -> String {
    get { book[keyPath: keyPath].flatMap(String.init(describing:)) ?? "" }
    set { book[keyPath: keyPath] = Int(newValue) }
  }
}

/// A form that allows editing the metadata of its book and its cover image.
struct BookEditView: View {
  private enum SheetDestination: Identifiable {
    case coverImageSource

    var id: String {
      switch self {
      case .coverImageSource:
        "cover-image-source"
      }
    }
  }

  @ObservedObject var model: BookEditViewModel
  var canPasteCoverImage: () -> Bool = { UIPasteboard.general.image != nil }
  var canScanCoverImage: () -> Bool = { false }
  var pasteCoverImage: () -> Void = {}
  var scanCoverImage: () -> Void = {}
  var searchCoverImage: () -> Void = {}

  @State private var sheetDestination: SheetDestination?

  var body: some View {
    Form {
      Section(header: Text("Cover Image")) {
        coverImageView
      }
      .listRowBackground(Color(uiColor: .grailSecondaryGroupedBackground))

      Section(header: Text("Book Details")) {
        CaptionedRow(caption: "Title", text: $model.book.title)
        CaptionedRow(caption: "Author", value: $model.book.authors, format: .commaSeparatedList)
        CaptionedRow(caption: "Tags (comma separated)", value: $model.book.tags, format: .commaSeparatedList)
        CaptionedRow(caption: "Publisher", text: $model[asString: \.publisher])
        CaptionedRow(caption: "Year Published", text: $model[asString: \.yearPublished])
        CaptionedRow(caption: "Original Year Published", text: $model[asString: \.originalYearPublished])
        CaptionedRow(caption: "ISBN", text: $model[asString: \.isbn])
        CaptionedRow(caption: "ISBN-13", text: $model[asString: \.isbn13])
      }
      .listRowBackground(Color(uiColor: .grailSecondaryGroupedBackground))
    }
    .grailListBackground()
    .sheet(item: $sheetDestination) { destination in
      switch destination {
      case .coverImageSource:
        CoverImageSourceSheet(
          hasCoverImage: model.coverImage != nil,
          canPasteCoverImage: canPasteCoverImage(),
          canScanCoverImage: canScanCoverImage(),
          pasteCoverImage: pasteCoverImage,
          scanCoverImage: scanCoverImage,
          searchCoverImage: searchCoverImage,
          deleteCoverImage: {
            withAnimation {
              model.coverImage = nil
            }
          }
        )
      }
    }
  }

  @ViewBuilder var coverImageView: some View {
    ZStack(alignment: .bottomTrailing) {
      Group {
        if let coverImage = model.coverImage {
          Image(uiImage: coverImage)
            .resizable()
            .scaledToFit()
        } else {
          Image(systemName: "square.slash")
            .resizable()
            .scaledToFit()
            .foregroundStyle(.secondary)
            .padding(32)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: 200)

      Button {
        sheetDestination = .coverImageSource
      } label: {
        Image(systemName: "pencil")
          .font(.headline)
          .foregroundStyle(Color(uiColor: .grailBackground))
          .frame(width: 44, height: 44)
          .background(Circle().fill(Color(uiColor: .grailTint)))
          .shadow(radius: 2, y: 1)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Change cover image")
      .padding(8)
    }
  }
}

private struct CoverImageSourceSheet: View {
  @Environment(\.dismiss) private var dismiss

  let hasCoverImage: Bool
  let canPasteCoverImage: Bool
  let canScanCoverImage: Bool
  let pasteCoverImage: () -> Void
  let scanCoverImage: () -> Void
  let searchCoverImage: () -> Void
  let deleteCoverImage: () -> Void

  var body: some View {
    NavigationView {
      List {
        if canPasteCoverImage {
          Button {
            pasteCoverImage()
            dismiss()
          } label: {
            Label("Paste Cover", systemImage: "doc.on.clipboard")
          }
        }

        #if !targetEnvironment(macCatalyst)
          if canScanCoverImage {
            Button {
              scanCoverImage()
              dismiss()
            } label: {
              Label("Scan Cover", systemImage: "doc.viewfinder")
            }
          }
        #endif

        Button {
          searchCoverImage()
          dismiss()
        } label: {
          Label("Search Google Books", systemImage: "magnifyingglass")
        }

        if hasCoverImage {
          Button(role: .destructive) {
            deleteCoverImage()
            dismiss()
          } label: {
            Label("Delete Cover", systemImage: "trash")
          }
        }
      }
      .navigationTitle("Cover Image")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
      }
    }
  }
}

/// Show a floating caption over a text row
///
/// See https://medium.com/swlh/simpler-better-floating-label-textfields-in-swiftui-24f7d06da8b8
struct CaptionedRow<Format: ParseableFormatStyle>: View where Format.FormatOutput == String {
  private enum Storage {
    case text(Binding<String>)
    case formatted(Binding<Format.FormatInput>, Format)
    case optionalFormatted(Binding<Format.FormatInput?>, Format)
  }

  let caption: String
  private var storage: Storage

  init(caption: String, value: Binding<Format.FormatInput>, format: Format) {
    self.caption = caption
    self.storage = .formatted(value, format)
  }

  init(caption: String, value: Binding<Format.FormatInput?>, format: Format) {
    self.caption = caption
    self.storage = .optionalFormatted(value, format)
  }

  private var text: String {
    switch storage {
    case .text(let binding):
      binding.wrappedValue
    case .formatted(let binding, let format):
      format.format(binding.wrappedValue)
    case .optionalFormatted(let binding, let format):
      binding.wrappedValue.flatMap { format.format($0) } ?? ""
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(caption).font(.caption).foregroundColor(.secondary)
        .opacity(text.isEmpty ? 0 : 1)
        .offset(y: text.isEmpty ? 20 : 0)
      switch storage {
      case .text(let stringBinding):
        TextField(caption, text: stringBinding.animation())
      case .formatted(let binding, let formatStyle):
        TextField(caption, value: binding, format: formatStyle)
      case .optionalFormatted(let binding, let formatStyle):
        TextField(caption, value: binding, format: formatStyle)
      }
    }.animation(.default, value: text)
  }
}

extension CaptionedRow where Format == CommaSeparatedListFormatStyle {
  init(caption: String, text: Binding<String>) {
    self.caption = caption
    self.storage = .text(text)
  }
}

struct CommaSeparatedListFormatStyle: ParseableFormatStyle {
  var parseStrategy = CommaSeparatedListFormatParseStrategy()

  func format(_ value: [String]) -> String {
    value
      .filter { !$0.isEmpty }
      .joined(separator: ", ")
  }
}

extension ParseableFormatStyle where Self == CommaSeparatedListFormatStyle {
  static var commaSeparatedList: CommaSeparatedListFormatStyle { CommaSeparatedListFormatStyle() }
}

struct CommaSeparatedListFormatParseStrategy: ParseStrategy {
  func parse(_ value: String) throws -> [String] {
    value.split(separator: ",")
      .map(String.init)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }
}

struct BookEditView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      BookEditView(model: BookEditViewModel(
        book: AugmentedBook(
          title: "Dune",
          authors: ["Frank Herbert"],
          review: "This is a review",
          rating: 4,
          dateAdded: nil
        ),
        coverImage: nil
      ))
    }
  }
}

struct GrailListBackgroundModifier: ViewModifier {
  func body(content: Content) -> some View {
    if #available(macCatalyst 16.0, iOS 16.0, *) {
      content
        .background(Color(.grailGroupedBackground))
        .scrollContentBackground(.hidden)
    } else {
      content
    }
  }
}

extension View {
  @ViewBuilder func `if`(_ condition: Bool, transform: (Self) -> some View) -> some View {
    if condition {
      transform(self)
    } else {
      self
    }
  }

  func grailListBackground() -> some View {
    modifier(GrailListBackgroundModifier())
  }
}
