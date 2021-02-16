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
        const importKindleHighlights = () => {
            var _a, _b;
            const bookTitle = (_a = window.document.querySelector("h3.kp-notebook-metadata")) === null || _a === void 0 ? void 0 : _a.textContent;
            const bookAuthor = (_b = window.document.querySelector("span.kp-notebook-metadata.a-color-secondary")) === null || _b === void 0 ? void 0 : _b.textContent;
            const annotations = window.document.getElementById("kp-notebook-annotations");
            const highlightDomElements = (annotations === null || annotations === void 0 ? void 0 : annotations.querySelectorAll("div.a-row.a-spacing-base")) || [];
            const locationRE = / (\S*)\)/;
            const quotes = Array.from(highlightDomElements).flatMap(e => {
                var _a, _b, _c, _d, _e;
                console.log(`Trying to match ${(_a = e.querySelector("span#annotationHighlightHeader")) === null || _a === void 0 ? void 0 : _a.textContent}`);
                const location = (_c = (_b = e.querySelector("span#annotationHighlightHeader")) === null || _b === void 0 ? void 0 : _b.textContent) === null || _c === void 0 ? void 0 : _c.match(/\u00a0(\S+)$/);
                const locationSuffix = location ? ` (${location[1]})` : "";
                const highlight = (_e = (_d = e.querySelector("div.kp-notebook-highlight")) === null || _d === void 0 ? void 0 : _d.textContent) === null || _e === void 0 ? void 0 : _e.trim();
                return highlight ? [`> ${highlight}${locationSuffix}`] : [];
            }).join("\n\n");
            return `# ${bookTitle}: ${bookAuthor}\n\n${quotes}`;
        };
        importKindleHighlights();
      """#
    ),
  ]
}
