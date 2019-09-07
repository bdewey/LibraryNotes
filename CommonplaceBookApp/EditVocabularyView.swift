// Copyright © 2017-present Brian's Brain. All rights reserved.

import MiniMarkdown
import SwiftUI

/// An "Add Vocabulary" view, designed to be presented modally inside a UIKit app.
/// It will dismiss automatically on tapping Done.
struct EditVocabularyView: View {
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
              self.imageSearchRequest.searchTerm = self.vocabularyTemplate.front.text
              self.imageSearchRequest.performSearch()
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
}

struct AddVocabularyViewPreviews: PreviewProvider {
  static var previews: some View {
    let template = VocabularyChallengeTemplate(
      front: VocabularyChallengeTemplate.Word(text: "", language: "es"),
      back: VocabularyChallengeTemplate.Word(text: "", language: "en"),
      parsingRules: ParsingRules()
    )
    return EditVocabularyView(vocabularyTemplate: template)
      .environmentObject(ImageSearchRequest())
  }
}
