// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import MiniMarkdown
import SwiftUI

/// An "Add Vocabulary" view, designed to be presented modally inside a UIKit app.
/// It will dismiss automatically on tapping Done.
struct EditVocabularyView: View {
  let notebook: NoteArchiveDocument
  @EnvironmentObject var imageSearchRequest: ImageSearchRequest
  @ObservedObject var vocabularyTemplate: VocabularyChallengeTemplate
  var onCommit: () -> Void = {}

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

  private var doneButton: some View {
    Button("Done", action: onCommit)
      .disabled(!vocabularyTemplate.isValid)
  }

  private var selectedImage: SwiftUI.Image? {
    if
      let key = vocabularyTemplate.imageAsset,
      let data = notebook.data(for: key),
      let uiImage = UIImage(data: data) {
      return Image(uiImage: uiImage)
    } else {
      return nil
    }
  }

  private func onSelectedImage(encodedImage: EncodedImage) {
    DDLogInfo("Selected image: \(encodedImage)")
    let key = notebook.storeAssetData(encodedImage.data, typeHint: encodedImage.encoding)
    DDLogInfo("Saved image data as asset \(key)")
    vocabularyTemplate.imageAsset = key
  }
}

struct AddVocabularyViewPreviews: PreviewProvider {
  static var previews: some View {
    let template = VocabularyChallengeTemplate(
      front: VocabularyChallengeTemplate.Word(text: "", language: "es"),
      back: VocabularyChallengeTemplate.Word(text: "", language: "en"),
      parsingRules: ParsingRules()
    )
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("test.notebundle")
    return EditVocabularyView(notebook: NoteArchiveDocument(fileURL: url, parsingRules: ParsingRules.commonplace), vocabularyTemplate: template)
      .environmentObject(ImageSearchRequest())
  }
}
