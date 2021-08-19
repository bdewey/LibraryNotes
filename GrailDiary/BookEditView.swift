import BookKit
import SwiftUI

struct BookEditView: View {
  @Binding var book: AugmentedBook
  var body: some View {
    Form {
      Section(header: Text("Book Details")) {
        TextField("Title", text: $book.title)
        TextField("Author", text: Binding(
          get: { book.authors.joined(separator: ",") },
          set: { book.authors = $0.split(separator: ",").map(String.init) }
        ))
        TextField("Year Published", text: Binding(
          get: { book.yearPublished.flatMap(String.init(describing:)) ?? "" },
          set: { book.yearPublished = Int($0) }
        ))
        TextField("Original Year Published", text: Binding(
          get: { book.originalYearPublished.flatMap(String.init(describing:)) ?? "" },
          set: { book.originalYearPublished = Int($0) }
        ))
        TextField("ISBN", text: Binding(
          get: { book.isbn ?? "" },
          set: { book.isbn = $0 }
        ))
        TextField("ISBN-13", text: Binding(
          get: { book.isbn13 ?? "" },
          set: { book.isbn13 = $0 }
        ))
      }
    }
  }
}

struct BookEditView_Previews: PreviewProvider {
  static var previews: some View {
    BookEditView(book: .constant(AugmentedBook(
      title: "Dune",
      authors: ["Frank Herbert"],
      review: "This is a review",
      rating: 4,
      dateAdded: nil
    )))
  }
}
