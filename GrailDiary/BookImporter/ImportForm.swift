// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import SwiftUI
import UniformTypeIdentifiers

/// A form that lets the user input parameters for a book import job
struct ImportForm: View {
  var importAction: (BookImportRequest<URL>) -> Void
  @State private var downloadCoverImages = false
  @State private var dryRun = true
  @State private var showDocumentPicker = false
  @State private var hashtags = ""
  @State private var selectedURL: URL?
  @Environment(\.dismiss) var dismiss

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Download")) {
          Toggle("Cover Images", isOn: $downloadCoverImages)
          Toggle("Dry Run", isOn: $dryRun)
        }.listRowBackground(Color(uiColor: .grailSecondaryGroupedBackground))
        Section(header: Text("Hashtags (Optional)"), footer: Text("Enter #hashtags for all imported books. Example: #goodreads")) {
          TextField("#hashtag", text: $hashtags)
        }.listRowBackground(Color(uiColor: .grailSecondaryGroupedBackground))
        Section(footer: Text(verbatim: selectedURL?.lastPathComponent ?? "")) {
          Button("Select File") {
            showDocumentPicker = true
          }.listRowBackground(Color(uiColor: .grailSecondaryGroupedBackground))
        }
      }
      .navigationTitle("Import Books")
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: dispatchImportRequest) {
            Text("Import").bold()
          }.disabled(selectedURL == nil)
        }
      }
    }
    .navigationViewStyle(StackNavigationViewStyle())
    .sheet(isPresented: $showDocumentPicker, content: {
      DocumentPickerView(contentTypes: [.json, .commaSeparatedText]) { urls in
        selectedURL = urls.first
      }
    })
    .tint(Color(UIColor.grailTint))
  }

  func dispatchImportRequest() {
    guard let selectedURL = selectedURL else {
      return
    }
    let importRequest = BookImportRequest(item: selectedURL, hashtags: hashtags, downloadCoverImages: downloadCoverImages, dryRun: dryRun)
    importAction(importRequest)
  }
}

struct ImportForm_Previews: PreviewProvider {
  static var previews: some View {
    ImportForm(importAction: { _ in })
//      .previewDevice("iPod touch (7th generation)")
  }
}
