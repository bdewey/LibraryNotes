// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import Foundation
import IGListKit

public protocol HashtagDataSourceDelegate: class {
  func hashtagDataSourceDidClearHashtag()
  func hashtagDataSourceDidSelectHashtag(_ hashtag: String)
}

public final class HashtagDataSource: NSObject, ListAdapterDataSource {
  public init(index: DocumentPropertiesIndex, stylesheet: Stylesheet) {
    self.index = index
    self.stylesheet = stylesheet
  }

  public weak var delegate: HashtagDataSourceDelegate?
  public let index: DocumentPropertiesIndex
  private let stylesheet: Stylesheet

  public func objects(for listAdapter: ListAdapter) -> [ListDiffable] {
    var results: [ListDiffable] = [
      MenuItem(
        label: NSAttributedString(
          string: "All notes",
          attributes: stylesheet.attributes(style: .body2)
        ),
        didSelect: { [weak self] in self?.delegate?.hashtagDataSourceDidClearHashtag() }
      ),
      MenuItem(
        label: NSAttributedString(
          string: "Hashtags",
          attributes: stylesheet.attributes(
            style: .caption,
            emphasis: .darkTextMediumEmphasis
          )
        )
      ),
    ]
    let hashtags = index.properties.values.reduce(into: Set<String>()) { (hashtags, props) in
      hashtags.formUnion(props.hashtags)
    }
    let hashtagDiffables = Array(hashtags).sorted().map { (hashtag) in
      MenuItem(
        label: NSAttributedString(
          string: hashtag,
          attributes: stylesheet.attributes(style: .body2, emphasis: .darkTextHighEmphasis)
        ),
        didSelect: { [weak self] in self?.delegate?.hashtagDataSourceDidSelectHashtag(hashtag) }
      )
    }
    results.append(contentsOf: hashtagDiffables)
    return results
  }

  public func listAdapter(
    _ listAdapter: ListAdapter,
    sectionControllerFor object: Any
  ) -> ListSectionController {
    return MenuSectionController(stylesheet: stylesheet)
  }

  public func emptyView(for listAdapter: ListAdapter) -> UIView? {
    return nil
  }
}
