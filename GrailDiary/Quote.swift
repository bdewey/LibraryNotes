// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import SwiftUI

struct QuoteViewModel: Identifiable {
  let id: String
  let quote: ParsedString
  let attributionTitle: ParsedString
}

struct Quote: View {
  let viewModel: QuoteViewModel
  var syntaxModifiers: [SyntaxTreeNodeType: ParsedStringView.TextModifier] = [
    .delimiter: { _ in Text("") },
    .strongEmphasis: { $0.bold() },
    .emphasis: { $0.italic() },
  ]

  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        ParsedStringView(
          parsedString: viewModel.quote,
          syntaxModifiers: syntaxModifiers,
          leafModifier: { $0.font(.body) }
        ).padding([.bottom])
        HStack(spacing: 0) {
          Text("— ").font(.caption).foregroundColor(.gray)
          ParsedStringView(
            parsedString: viewModel.attributionTitle,
            syntaxModifiers: syntaxModifiers,
            leafModifier: { $0.font(.caption).foregroundColor(.gray) }
          )
        }
      }
      Spacer()
    }
    .padding()
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(Color.gray)
    )
    .background(VisualEffectBlur(blurStyle: .systemMaterial).cornerRadius(10))
    .padding()
  }
}

struct VisualEffectBlur<Content: View>: View {
    var blurStyle: UIBlurEffect.Style
    var vibrancyStyle: UIVibrancyEffectStyle?
    var content: Content

    init(blurStyle: UIBlurEffect.Style = .systemMaterial, vibrancyStyle: UIVibrancyEffectStyle? = nil, @ViewBuilder content: () -> Content) {
        self.blurStyle = blurStyle
        self.vibrancyStyle = vibrancyStyle
        self.content = content()
    }

    var body: some View {
        Representable(blurStyle: blurStyle, vibrancyStyle: vibrancyStyle, content: ZStack { content })
            .accessibility(hidden: Content.self == EmptyView.self)
    }
}

extension VisualEffectBlur {
    struct Representable<Content: View>: UIViewRepresentable {
        var blurStyle: UIBlurEffect.Style
        var vibrancyStyle: UIVibrancyEffectStyle?
        var content: Content

        func makeUIView(context: Context) -> UIVisualEffectView {
            context.coordinator.blurView
        }

        func updateUIView(_ view: UIVisualEffectView, context: Context) {
            context.coordinator.update(content: content, blurStyle: blurStyle, vibrancyStyle: vibrancyStyle)
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(content: content)
        }
    }
}

extension VisualEffectBlur.Representable {
    class Coordinator {
        let blurView = UIVisualEffectView()
        let vibrancyView = UIVisualEffectView()
        let hostingController: UIHostingController<Content>

        init(content: Content) {
            hostingController = UIHostingController(rootView: content)
            hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            hostingController.view.backgroundColor = nil
            blurView.contentView.addSubview(vibrancyView)
            blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            vibrancyView.contentView.addSubview(hostingController.view)
            vibrancyView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }

        func update(content: Content, blurStyle: UIBlurEffect.Style, vibrancyStyle: UIVibrancyEffectStyle?) {
            hostingController.rootView = content
            let blurEffect = UIBlurEffect(style: blurStyle)
            blurView.effect = blurEffect
            if let vibrancyStyle = vibrancyStyle {
                vibrancyView.effect = UIVibrancyEffect(blurEffect: blurEffect, style: vibrancyStyle)
            } else {
                vibrancyView.effect = nil
            }
            hostingController.view.setNeedsDisplay()
        }
    }
}

extension VisualEffectBlur where Content == EmptyView {
    init(blurStyle: UIBlurEffect.Style = .systemMaterial) {
        self.init( blurStyle: blurStyle, vibrancyStyle: nil) {
            EmptyView()
        }
    }
}

private let quoteStrings = [
  "> In retrospect, I see that this was my education, the one that would matter: the hours I spent sitting at a borrowed desk, struggling to parse narrow strands of Mormon doctrine in mimicry of a brother who’d deserted me. The skill I was learning was a crucial one, the patience to read things I could not yet understand. (62)\n\n\n\n\n",
  "> I'll be back.",
]

struct Quote_Previews: PreviewProvider {
  static var previews: some View {
    VStack {
      ForEach(quoteStrings.indices, id: \.self) { index in
        let viewModel = QuoteViewModel(
          id: "\(index)",
          quote: ParsedString(String(quoteStrings[index].strippingLeadingAndTrailingWhitespace), grammar: MiniMarkdownGrammar.shared),
          attributionTitle: ParsedString("# _Educated_, Tara Westover (2019)", grammar: MiniMarkdownGrammar.shared)
        )
        Quote(viewModel: viewModel)
      }
    }
  }
}
