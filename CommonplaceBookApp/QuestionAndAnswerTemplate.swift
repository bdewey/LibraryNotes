//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

import Foundation
import UIKit

public extension ChallengeTemplateType {
  static let questionAndAnswer = ChallengeTemplateType(rawValue: "prompt=qanda", class: QuestionAndAnswerTemplate.self)
}

/// Generates challenges from QuestionAndAnswer minimarkdown nodes.
public struct QuestionAndAnswerTemplate: ChallengeTemplate {
  public init(rawValue: String) {
    self.markdown = rawValue
  }

  public var templateIdentifier: ChallengeTemplateIdentifier?

  /// The Q&A node.
  private let markdown: String
  public var rawValue: String { markdown }

  // MARK: - Public

  public var type: ChallengeTemplateType { return .questionAndAnswer }

  public static func extract(from parsedString: ParsedString) -> [QuestionAndAnswerTemplate] {
    guard let root = try? parsedString.result.get() else { return [] }
    return AnchoredNode(node: root, startIndex: 0)
      .findNodes(where: { $0.type == .questionAndAnswer })
      .map {
        let chars = parsedString[$0.range]
        return String(utf16CodeUnits: chars, count: chars.count)
      }
      .compactMap {
        QuestionAndAnswerTemplate(rawValue: $0)
      }
  }

  /// The single challenge from this template: Ourselves!
  public var challenges: [Challenge] { return [self] }
}

extension QuestionAndAnswerTemplate: Challenge {
  public var challengeIdentifier: ChallengeIdentifier {
    ChallengeIdentifier(noteId: templateIdentifier!.noteId, promptKey: templateIdentifier!.promptKey, promptIndex: 0)
  }

  public func challengeView(database: NoteDatabase, properties: CardDocumentProperties) -> ChallengeView {
    let view = TwoSidedCardView(frame: .zero)
    view.context = ParsedAttributedString(string: properties.attributionMarkdown, settings: .plainText(textStyle: .subheadline, textColor: .secondaryLabel, extraAttributes: [.kern: 2.0]))
    // TODO: Need to re-invent images :-(
//    document.addImageRenderer(to: &renderer.renderFunctions)
    let formattedString = ParsedAttributedString(string: markdown, settings: .plainText(textStyle: .body))
    if let node = try? formattedString.rawString.result.get() {
      let anchoredNode = AnchoredNode(node: node, startIndex: 0)
      if let question = anchoredNode.first(where: { $0.type == .qnaQuestion }) {
        view.front = formattedString.attributedSubstring(from: formattedString.range(forRawStringRange: question.range)).trimmingTrailingWhitespace()
      }
      if let answer = anchoredNode.first(where: { $0.type == .qnaAnswer }) {
        view.back = formattedString.attributedSubstring(from: formattedString.range(forRawStringRange: answer.range)).trimmingTrailingWhitespace()
      }
    }
    return view
  }
}
