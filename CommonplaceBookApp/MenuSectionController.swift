// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import Foundation
import IGListKit

public final class MenuSectionController: ListSectionController {

  public init(stylesheet: Stylesheet) {
    self.stylesheet = stylesheet
    super.init()
  }

  private let stylesheet: Stylesheet
  private var object: MenuItem?

  public override func sizeForItem(at index: Int) -> CGSize {
    return CGSize(width: collectionContext!.containerSize.width, height: 48)
  }

  public override func cellForItem(at index: Int) -> UICollectionViewCell {
    let cell = collectionContext!.dequeueReusableCell(
      of: TextCollectionViewCell.self,
      for: self,
      at: index
    ) as! TextCollectionViewCell // swiftlint:disable:this force_cast
    cell.backgroundColor = stylesheet.colorScheme.surfaceColor
    cell.textLabel.attributedText = object!.label
    return cell
  }

  public override func didSelectItem(at index: Int) {
    guard let menuItem = object else { return }
    menuItem.didSelect?()
  }

  public override func didUpdate(to object: Any) {
    self.object = (object as! MenuItem) // swiftlint:disable:this force_cast
  }
}
