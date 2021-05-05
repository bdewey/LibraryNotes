// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import SwiftUI

struct Quote: View {
  let quote: QuoteViewModel

  var body: some View {
    HStack {
      quote.quote.makeText(
        conversionFunctions: [
          .delimiter: { _ in Text("") },
          .strongEmphasis: { $0.bold() },
          .emphasis: { $0.italic() },
        ]
      )
      Spacer()
    }
    .padding()
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(Color.gray)
    )
    .padding()
  }
}

private let quoteStrings = [
  "> In retrospect, I see that this was my education, the one that would matter: the hours I spent sitting at a borrowed desk, struggling to parse narrow strands of Mormon doctrine in mimicry of a brother who’d deserted me. The skill I was learning was a crucial one, the patience to read things I could not yet understand. (62)",
  "> I'll be back.",
]

struct Quote_Previews: PreviewProvider {
  static var previews: some View {
    VStack {
      ForEach(quoteStrings.indices, id: \.self) { index in
        let viewModel = QuoteViewModel(
          id: "\(index)",
          quote: ParsedString(quoteStrings[index], grammar: MiniMarkdownGrammar.shared)
        )
        Quote(quote: viewModel)
      }
    }
  }
}
