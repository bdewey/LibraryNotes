// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import Foundation
import IGListKit

// TODO: Make a generic ListDiffable for wrapped values?
public final class Hashtag: ListDiffable {
  public let value: String

  public init(_ value: String) {
    self.value = value
  }

  public func diffIdentifier() -> NSObjectProtocol {
    return value as NSString
  }

  public func isEqual(toDiffableObject object: ListDiffable?) -> Bool {
    guard let otherWrapper = object as? Hashtag else { return false }
    return value == otherWrapper.value
  }
}

public final class HashtagSectionController: ListSectionController {

  public init(stylesheet: Stylesheet) {
    self.stylesheet = stylesheet
    super.init()
  }

  private let stylesheet: Stylesheet
  private var object: Hashtag?

  public override func sizeForItem(at index: Int) -> CGSize {
    return CGSize(width: collectionContext!.containerSize.width, height: 44)
  }

  public override func cellForItem(at index: Int) -> UICollectionViewCell {
    let cell = collectionContext!.dequeueReusableCell(
      of: HashtagCollectionViewCell.self,
      for: self,
      at: index
    ) as! HashtagCollectionViewCell // swiftlint:disable:this force_cast
    cell.backgroundColor = stylesheet.colorScheme.darkSurfaceColor
    cell.hashtagLabel.attributedText = NSAttributedString(
      string: object?.value ?? "(null)",
      attributes: stylesheet.attributes(style: .body2, emphasis: .darkTextMediumEmphasis)
    )
    return cell
  }

  public override func didUpdate(to object: Any) {
    self.object = (object as! Hashtag) // swiftlint:disable:this force_cast
  }
}
