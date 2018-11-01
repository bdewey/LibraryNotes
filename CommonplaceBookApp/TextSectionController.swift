// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import Foundation
import IGListKit

typealias TextListDiffable = ObjectListDiffable<NSAttributedString>

public final class TextSectionController: ListSectionController {

  public init(stylesheet: Stylesheet) {
    self.stylesheet = stylesheet
    super.init()
  }

  private let stylesheet: Stylesheet
  private var object: TextListDiffable?

  public override func sizeForItem(at index: Int) -> CGSize {
    return CGSize(width: collectionContext!.containerSize.width, height: 48)
  }

  public override func cellForItem(at index: Int) -> UICollectionViewCell {
    let cell = collectionContext!.dequeueReusableCell(
      of: TextCollectionViewCell.self,
      for: self,
      at: index
    ) as! TextCollectionViewCell // swiftlint:disable:this force_cast
    cell.backgroundColor = stylesheet.colorScheme.darkSurfaceColor
    cell.textLabel.attributedText = object!.value
    return cell
  }

  public override func didUpdate(to object: Any) {
    self.object = (object as! TextListDiffable) // swiftlint:disable:this force_cast
  }
}
