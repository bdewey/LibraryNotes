// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import SwiftUI
import UniformTypeIdentifiers

/// A form that lets the user input parameters for a book import job
struct ImportForm: View {
  var importAction: ([URL], String, Bool, Bool) -> Void
  @State private var downloadCoverImages = false
  @State private var dryRun = true
  @State private var showDocumentPicker = false
  @State private var hashtags = ""

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Download")) {
          Toggle("Cover Images", isOn: $downloadCoverImages)
          Toggle("Dry Run", isOn: $dryRun)
        }
        Section(header: Text("Hashtags (Optional)"), footer: Text("Enter #hashtags for all imported books. Example: #goodreads")) {
          TextField("#hashtag", text: $hashtags)
        }
        Button("Select File") {
          showDocumentPicker = true
        }
      }
      .navigationTitle("Import Books")
    }
    .navigationViewStyle(StackNavigationViewStyle())
    .sheet(isPresented: $showDocumentPicker, content: {
      DocumentPickerView(contentTypes: [.json, .commaSeparatedText]) { urls in
        importAction(urls, hashtags, downloadCoverImages, dryRun)
      }
    })
  }
}

struct ImportForm_Previews: PreviewProvider {
  static var previews: some View {
    ImportForm(importAction: { _, _, _, _ in })
//      .previewDevice("iPod touch (7th generation)")
  }
}
