// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import MiniMarkdown
import SwiftUI

/// An "Add Vocabulary" view, designed to be presented modally inside a UIKit app.
/// It will dismiss automatically on tapping Done.
struct EditVocabularyView: View {
  /// Notebook -- needed to save image assets.
  let notebook: NoteStorage

  /// Holds the results from an image search.
  @EnvironmentObject var imageSearchRequest: ImageSearchRequest

  /// The vocabulary template we are filling out.
  @ObservedObject var vocabularyTemplate: VocabularyChallengeTemplate

  /// Action to take on commit.
  var onCommit: () -> Void = {}

  /// Which field is supposed to have focus?
  private enum FirstResponder {
    case spanish
    case english
    case none
  }

  @State private var firstResponder = FirstResponder.spanish

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Vocabulary")) {
          LocaleAwareTextField(
            "Spanish",
            text: $vocabularyTemplate.front.text,
            onCommit: {
              self.firstResponder = .english
              self.imageSearchRequest.performSearch(for: self.vocabularyTemplate.front.text)
            },
            shouldBeFirstResponder: firstResponder == .spanish
          ).customAutocapitalization(.none).locale(Locale(identifier: "es-MX"))
          LocaleAwareTextField(
            "English",
            text: $vocabularyTemplate.back.text,
            onCommit: {
              self.firstResponder = .none
              self.onCommit()
            },
            shouldBeFirstResponder: firstResponder == .english
          ).customAutocapitalization(.none)
          selectedImage?.resizable().aspectRatio(contentMode: .fit).frame(height: 50)
        }
        if imageSearchRequest.searchResults != nil {
          Section(header: Text("Available images")) {
            ImageSearchResultsView(searchResults: imageSearchRequest.searchResults, onSelectedImage: self.onSelectedImage)
              .frame(height: 200)
          }
        }
      }
      .navigationBarTitle("Add Vocabulary")
      .navigationBarItems(trailing: doneButton)
    }
    .navigationViewStyle(StackNavigationViewStyle())
  }

  /// The "Done" button -- factored out because of disabled logic.
  private var doneButton: some View {
    Button("Done", action: onCommit)
      .disabled(!vocabularyTemplate.isValid)
  }

  /// The current selected image for the vocabulary association.
  private var selectedImage: SwiftUI.Image? {
    if
      let key = vocabularyTemplate.imageAsset,
      let data = try? notebook.data(for: key),
      let uiImage = UIImage(data: data) {
      return Image(uiImage: uiImage)
    } else {
      return nil
    }
  }

  /// Handles that the selected image changed.
  // TODO: Only store asset data when we commit this association?
  private func onSelectedImage(encodedImage: EncodedImage) {
    DDLogInfo("Selected image: \(encodedImage)")
    let key = encodedImage.data.sha1Digest() + "." + encodedImage.encoding
    do {
      let actualKey = try notebook.storeAssetData(encodedImage.data, key: key)
      vocabularyTemplate.imageAsset = actualKey
      DDLogInfo("Saved image data as asset \(actualKey)")
    } catch {
      DDLogError("Unexpected error saving image: \(error)")
    }
  }
}
