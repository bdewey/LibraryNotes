// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import SwiftUI

struct QuotesList: View {
  let quotes: [QuoteViewModel]

  var body: some View {
    ScrollView {
      LazyVStack {
        ForEach(quotes) { quote in
          Quote(viewModel: quote)
        }
      }
    }
  }
}

struct QuotesList_Previews: PreviewProvider {
  static var previews: some View {
    let strings: [String] = [
      "> This is a simple quote",
      "> This is a quote with **bold** and *emphasis*.",
      "> This is a quote with page number attribution. (38)",
      "> This is a quote with source attribution. (Yoda)",
    ]
    let quotes = strings.enumerated().map { (index, quoteString) -> QuoteViewModel in
      QuoteViewModel(
        id: "\(index)",
        quote: ParsedString(quoteString, grammar: MiniMarkdownGrammar.shared),
        attributionTitle: ParsedString("# Bartlett's Familiar Quotations", grammar: MiniMarkdownGrammar.shared)
      )
    }
    return QuotesList(quotes: quotes)
      .previewDevice("iPod touch (7th generation)")
  }
}
