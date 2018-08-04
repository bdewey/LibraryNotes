// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation

import MiniMarkdown

fileprivate func defaultInlineRenderer(
  _ inline: MiniMarkdown.Inline,
  _ attributes: NSAttributedString.Attributes
) -> NSAttributedString {
  return NSAttributedString(
    string: String(inline.slice.substring),
    attributes: attributes.attributes
  )
}

struct AttributedStringRenderer {
  
  var stylesheet = MiniMarkdown.Stylesheet()
  
  typealias InlineRenderer = (MiniMarkdown.Inline, NSAttributedString.Attributes) -> NSAttributedString
  
  var text: InlineRenderer?
  var emphasis: InlineRenderer?
  var bold: InlineRenderer?
  var image: InlineRenderer?
  
  private func renderer(for type: MiniMarkdown.Inline.InlineType) -> InlineRenderer? {
    switch type {
    case .text:
      return text
    case .emphasis:
      return emphasis
    case .bold:
      return bold
    case .image:
      return image
    }
  }
  
  var listItem: BlockRenderer?
  
  private func renderer(for type: MiniMarkdown.Block.BlockType) -> BlockRenderer? {
    switch type {
    case .listItem(type: _):
      return listItem
    default:
      return nil
    }
  }
  
  typealias BlockRenderer = (NSMutableAttributedString, MiniMarkdown.Block, NSAttributedString.Attributes) -> Void
  
  func render(markdown: String, baseAttributes: NSAttributedString.Attributes) -> NSAttributedString {
    let result = NSMutableAttributedString()
    for block in markdown.miniMarkdownDocument {
      render(into: result, block: block, attributes: baseAttributes)
    }
    return result
  }
  
  func render(
    into attributedString: NSMutableAttributedString,
    block: MiniMarkdown.Block,
    attributes: NSAttributedString.Attributes
  ) {
    var attributes = attributes
    stylesheet.applyAttributes(for: block, to: &attributes)
    let renderer = self.renderer(for: block.type) ?? defaultBlockRenderer
    renderer(attributedString, block, attributes)
  }
  
  func render(
    into attributedString: NSMutableAttributedString,
    inline: MiniMarkdown.Inline,
    attributes: NSAttributedString.Attributes
  ) {
    var attributes = attributes
    stylesheet.applyAttributes(for: inline, to: &attributes)
    let renderer = self.renderer(for: inline.type) ?? defaultInlineRenderer
    let string = renderer(inline, attributes)
    attributedString.append(string)
  }
  
  public func defaultBlockRenderer(
    _ attributedString: NSMutableAttributedString,
    _ block: MiniMarkdown.Block,
    _ attributes: NSAttributedString.Attributes
    ) {
    switch block.type {
    case .list(type: _, items: let items):
      for item in items {
        render(into: attributedString, block: item, attributes: attributes)
      }
    default:
      for inline in block.inlines {
        render(into: attributedString, inline: inline, attributes: attributes)
      }
    }
  }
}
