// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

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

  func binding(keyPath: WritableKeyPath<AugmentedBook, [String]>) -> Binding<String> {
    Binding(
      get: { self.book[keyPath: keyPath].joined(separator: ", ") },
      set: { self.book[keyPath: keyPath] = $0.split(separator: ",")
        .map(String.init)
        .map { $0.trimmingCharacters(in: .whitespaces) }
      }
    )
  }

  func binding(keyPath: WritableKeyPath<AugmentedBook, [String]?>) -> Binding<String> {
    Binding(
      get: { self.book[keyPath: keyPath]?.joined(separator: ", ") ?? "" },
      set: { self.book[keyPath: keyPath] = $0.split(separator: ",")
        .map(String.init)
        .map { $0.trimmingCharacters(in: .whitespaces) }
      }
    )
  }

  func binding(keyPath: WritableKeyPath<AugmentedBook, Int?>) -> Binding<String> {
    Binding(
      get: { self.book[keyPath: keyPath].flatMap(String.init(describing:)) ?? "" },
      set: { self.book[keyPath: keyPath] = Int($0) }
    )
  }

  func binding(keyPath: WritableKeyPath<AugmentedBook, String?>) -> Binding<String> {
    Binding(
      get: { self.book[keyPath: keyPath] ?? "" },
      set: { self.book[keyPath: keyPath] = $0 }
    )
  }
}

/// A form that allows editing the metadata of its book and its cover image.
struct BookEditView: View {
  @ObservedObject var model: BookEditViewModel

  var body: some View {
    Form {
      Section(header: Text("Cover Image"), footer: Text("Long-press to paste a new image")) {
        coverImageView

          .contextMenu {
            Button {
              withAnimation {
                if let image = UIPasteboard.general.image {
                  model.coverImage = image
                }
              }
            } label: {
              Label("Paste", systemImage: "doc.on.clipboard")
            }

            Button(role: .destructive) {
              withAnimation {
                model.coverImage = nil
              }
            } label: {
              Label("Delete", systemImage: "trash")
            }.disabled(model.coverImage == nil)
          }
      }
      .listRowBackground(Color(uiColor: .grailSecondaryGroupedBackground))

      Section(header: Text("Book Details")) {
        CaptionedRow(caption: "Title", text: $model.book.title)
        CaptionedRow(caption: "Author", value: $model.book.authors, format: .commaSeparatedList)
        CaptionedRow(caption: "Tags (comma separated)", value: $model.book.tags, format: .commaSeparatedList)
        CaptionedRow(caption: "Publisher", text: model.binding(keyPath: \.publisher))
        CaptionedRow(caption: "Year Published", text: model.binding(keyPath: \.yearPublished))
        CaptionedRow(caption: "Original Year Published", text: model.binding(keyPath: \.originalYearPublished))
        CaptionedRow(caption: "ISBN", text: model.binding(keyPath: \.isbn))
        CaptionedRow(caption: "ISBN-13", text: model.binding(keyPath: \.isbn13))
      }
      .listRowBackground(Color(uiColor: .grailSecondaryGroupedBackground))
    }
    .grailListBackground()
  }

  @ViewBuilder var coverImageView: some View {
    if let coverImage = model.coverImage {
      Image(uiImage: coverImage).resizable().scaledToFit().frame(maxHeight: 200)
    } else {
      Image(systemName: "square.slash").resizable().scaledToFit().frame(maxHeight: 200)
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
      return binding.wrappedValue
    case .formatted(let binding, let format):
      return format.format(binding.wrappedValue)
    case .optionalFormatted(let binding, let format):
      return binding.wrappedValue.flatMap { format.format($0) } ?? ""
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
