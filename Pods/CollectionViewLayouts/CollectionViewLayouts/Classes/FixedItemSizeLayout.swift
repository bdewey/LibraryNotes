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

import CocoaLumberjack
import UIKit

// TODO: Clean up this file.
// swiftlint:disable line_length

public final class FixedItemSizeLayout: UICollectionViewLayout {
  var itemSize = CGSize.zero

  fileprivate func _computeItemSizeFromCollectionView(_ collectionView: UICollectionView) {
    let insetHeight: CGFloat = 64 + 49 // collectionView.contentInset.top + collectionView.contentInset.bottom
    itemSize = CGSize(width: collectionView.bounds.size.width, height: collectionView.bounds.size.height - insetHeight)
  }

  var countOfSections = 0
  var itemsPerSection: [Int] = []
  var countOfItems = 0

  override public func prepare() {
    guard let collectionView = self.collectionView else { return }
    _computeItemSizeFromCollectionView(collectionView)
    DDLogInfo("FixedItemSizeLayout.prepareLayout")
    prepareSectionCounts()
  }

  var transitioningToLayout: UICollectionViewLayout?
  var fullSizeIndexPathForTransition: IndexPath?
  var transitionOrigin: CGPoint?
  var transitionOriginNeedsScreenOffsetForFrame: CGRect?

  override public func prepareForTransition(from oldLayout: UICollectionViewLayout) {
    DDLogInfo(
      "FixedItemSizeLayout prepareForTransitionFromLayout \(oldLayout), " +
      "collectionView = \(String(describing: self.collectionView))"
    )
    let focusedIndexPath = self.collectionView?.indexPathsForSelectedItems?.first
    prepareForLayoutTransition(oldLayout, toFocusedIndexPath: focusedIndexPath!, targetContentOffset: self.collectionView?.contentOffset)
  }

  override public func prepareForTransition(to newLayout: UICollectionViewLayout) {
    DDLogInfo("FixedItemSizeLayout prepareForTransitionToLayout \(newLayout)")
    let focusedIndexPath = self.collectionView?.indexPathsForVisibleItems.first
    prepareForLayoutTransition(newLayout, toFocusedIndexPath: focusedIndexPath!, targetContentOffset: nil)
  }

  fileprivate func prepareForLayoutTransition(
    _ otherLayout: UICollectionViewLayout,
    toFocusedIndexPath indexPath: IndexPath,
    targetContentOffset: CGPoint?
  ) {
    prepareSectionCounts()
    transitioningToLayout = otherLayout
    fullSizeIndexPathForTransition = indexPath
    if self.collectionView != nil {
      _computeItemSizeFromCollectionView(self.collectionView!)
      transitionOrigin = frameForItemIndex(itemIndexForIndexPath(fullSizeIndexPathForTransition!)).origin
      if let oldAttributes = otherLayout.layoutAttributesForItem(at: fullSizeIndexPathForTransition!) {
        if targetContentOffset != nil {
          adjustTransitionOffsetForTargetContentOffset(targetContentOffset!, targetFrame: oldAttributes.frame)
        } else {
          transitionOriginNeedsScreenOffsetForFrame = oldAttributes.frame
        }
      }
      DDLogInfo("Transition origin: \(String(describing: transitionOrigin))")
    }
    DDLogInfo("Selected item: \(String(describing: fullSizeIndexPathForTransition))")
  }

  fileprivate func prepareSectionCounts() {
    guard let collectionView = self.collectionView else { return }
    countOfSections = collectionView.numberOfSections
    itemsPerSection = []
    countOfItems = 0
    for i in 0..<countOfSections {
      let itemsInSection = collectionView.numberOfItems(inSection: i)
      itemsPerSection.append(itemsInSection)
      countOfItems += itemsInSection
    }
  }

  override public func finalizeLayoutTransition() {
    DDLogInfo("FixedItemSizeLayout finalizeLayoutTransition")
    transitioningToLayout = nil
    fullSizeIndexPathForTransition = nil
    transitionOrigin = nil
  }

  override public var collectionViewContentSize: CGSize {
    DDLogLayout("FixedItemSizeLayout.collectionViewContentSize")
    return CGSize(width: itemSize.width * CGFloat(countOfItems), height: itemSize.height)
  }

  override public func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
    DDLogLayout("FixedItemSizeLayout.layoutAttributesForElementsInRect \(rect)")
    if itemSize.width == 0 {
      return nil
    }
    let minItemIndex = Int(floor(rect.minX / itemSize.width))
    let maxItemIndex = Int(ceil(rect.maxX / itemSize.width))
    var attributes: [UICollectionViewLayoutAttributes] = []
    for i in minItemIndex ... maxItemIndex {
      if let indexPath = indexPathForItemIndex(i) {
        let layoutAttributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        layoutAttributes.frame = frameForItemIndex(i)
        attributes.append(layoutAttributes)
      }
    }
    return attributes
  }

  override public func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
    if let transitioningToLayout = self.transitioningToLayout {
      if fullSizeIndexPathForTransition != nil && (fullSizeIndexPathForTransition! == indexPath) {
        // NOTHING -- fall through to normal case
      } else {
        let newAttributes = translateAttributes(transitioningToLayout.layoutAttributesForItem(at: indexPath))
        newAttributes?.alpha = 0
        DDLogLayout(
          "FixedItemSizeLayout delegating layout for \(indexPath): " +
          "\(String(describing: newAttributes))"
        )
        return newAttributes
      }
    }
    DDLogLayout("FixedItemSizeLayout.layoutAttributesForItemAtIndexPath \(indexPath)")
    let index = itemIndexForIndexPath(indexPath)
    let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
    attributes.frame = frameForItemIndex(index)
    attributes.zIndex = 1000
    return attributes
  }

  fileprivate func adjustTransitionOffsetForTargetContentOffset(_ targetContentOffset: CGPoint, targetFrame: CGRect) {
    guard var transitionOrigin = self.transitionOrigin else { return }
    let screenOffset = targetFrame.origin.y - targetContentOffset.y - self.collectionView!.contentInset.top
    transitionOrigin.y -= targetFrame.origin.y
    transitionOrigin.y += screenOffset
    self.transitionOrigin = transitionOrigin
  }

  fileprivate func translateAttributes(_ attributes: UICollectionViewLayoutAttributes?) -> UICollectionViewLayoutAttributes? {
    guard let unwrappedAttributes = attributes else { return nil }
    guard let translationOrigin = self.transitionOrigin else { return attributes }
    if let transitionOriginNeedsScreenOffsetForFrame = self.transitionOriginNeedsScreenOffsetForFrame,
      let targetContentOffset = (transitioningToLayout as? LayoutTargetContentOffsetDescribing)?.targetContentOffset {
      adjustTransitionOffsetForTargetContentOffset(targetContentOffset, targetFrame: transitionOriginNeedsScreenOffsetForFrame)
      self.transitionOriginNeedsScreenOffsetForFrame = nil
    }
    // swiftlint:disable:next force_cast
    let attributesCopy = unwrappedAttributes.copy() as! UICollectionViewLayoutAttributes
    attributesCopy.frame = attributesCopy.frame.offsetBy(dx: translationOrigin.x, dy: translationOrigin.y)
    return attributesCopy
  }

  override public func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
    if let transitioningToLayout = self.transitioningToLayout {
      let attributes = translateAttributes(transitioningToLayout.layoutAttributesForSupplementaryView(ofKind: elementKind, at: indexPath))
      attributes?.alpha = 0
      return attributes
    }
    return nil
  }

  override public func layoutAttributesForDecorationView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
    return nil
  }

  override public func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
    DDLogLayout("FixedItemSizeLayout.targetContentOffsetForProposedContentOffset \(proposedContentOffset)")
    return super.targetContentOffset(forProposedContentOffset: proposedContentOffset)
  }

  func indexPathForItemIndex(_ index: Int) -> IndexPath? {
    if index >= countOfItems || index < 0 {
      return nil
    }
    var remainingIndex = index
    for section in 0 ..< countOfSections {
      if remainingIndex < itemsPerSection[section] {
        return IndexPath(item: remainingIndex, section: section)
      }
      remainingIndex -= itemsPerSection[section]
    }
    assertionFailure("Did not compute item index properly?")
    return nil
  }

  func itemIndexForIndexPath(_ indexPath: IndexPath) -> Int {
    var index = 0
    for section in 0 ..< (indexPath as NSIndexPath).section {
      index += itemsPerSection[section]
    }
    index += (indexPath as NSIndexPath).row
    return index
  }

  func frameForItemIndex(_ index: Int) -> CGRect {
    let origin = CGPoint(x: CGFloat(index) * itemSize.width, y: 0)
    return CGRect(origin: origin, size: itemSize)
  }
}
