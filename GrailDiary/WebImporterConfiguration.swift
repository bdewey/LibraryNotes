// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

public struct WebImporterConfiguration {
  var title: String
  var image: UIImage?
  var initialURL: URL
  var importJavascript: String
}

extension WebImporterConfiguration {
  static let shared: [WebImporterConfiguration] = [
    .init(
      title: "Import Kindle Highlights",
      image: UIImage(systemName: "highlighter"),
      initialURL: URL(string: "https://read.amazon.com/notebook")!,
      importJavascript: #"""
        "use strict";
        var _a, _b;
        const title = (_a = window.document.querySelector("h3.kp-notebook-metadata")) === null || _a === void 0 ? void 0 : _a.textContent;
        const author = (_b = window.document.querySelector("p.kp-notebook-metadata.a-color-secondary")) === null || _b === void 0 ? void 0 : _b.textContent;
        const elements = Array.from(window.document.getElementsByClassName("kp-notebook-highlight"));
        const quotes = elements.map(e => `> ${e.textContent}`).join("\n\n");
        `# ${title}: ${author}\n\n${quotes}`;
      """#
    ),
  ]
}
