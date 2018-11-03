// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import Foundation
import IGListKit

public final class HashtagDataSource: NSObject, ListAdapterDataSourceWithAdapter {
  public init(index: DocumentPropertiesIndex, stylesheet: Stylesheet) {
    self.index = index
    self.stylesheet = stylesheet
    super.init()
    index.addDataSource(self)
  }

  deinit {
    index.removeDataSource(self)
  }

  private let index: DocumentPropertiesIndex
  private let stylesheet: Stylesheet
  public weak var adapter: ListAdapter?

  public func objects(for listAdapter: ListAdapter) -> [ListDiffable] {
    var results: [ListDiffable] = [
      MenuItem(
        label: NSAttributedString(
          string: "Hashtags",
          attributes: stylesheet.attributes(
            style: .caption,
            emphasis: .darkTextHighEmphasis
          )
        )
      ),
    ]
    let hashtags = index.properties.values.reduce(into: Set<String>()) { (hashtags, props) in
      hashtags.formUnion(props.value.hashtags)
    }
    let hashtagDiffables = Array(hashtags).sorted().map {
      MenuItem(
        label: NSAttributedString(
          string: $0,
          attributes: stylesheet.attributes(style: .body2, emphasis: .darkTextHighEmphasis)
        )
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
