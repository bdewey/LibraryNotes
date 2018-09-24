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

public protocol LayoutTargetContentOffsetDescribing {
  var targetContentOffset: CGPoint? { get }
}

/// In order for a collection view to have a CalendarLayout applied to it, its data source
/// must conform to this protocol.
///
/// The data source will have one section per month, one item per day.
public protocol CalendarDataSource: UICollectionViewDataSource {

  /// The calendar used for date calculations.
  var calendar: Calendar { get }

  // TODO: Change startDate / endDate to a Range<Date>

  /// The date associated with the first item in the data source.
  /// - precondition: startDate must be the first day of a month.
  var startDate: Date { get }

  /// The date associated with the last item in the data source.
  var endDate: Date { get }
}

extension CalendarDataSource {

  /// The total count of months spanned from startDate to endDate.
  public var countOfMonths: Int {
    return calendar.dateComponents([.month], from: startDate, to: endDate).month! + 1
  }

  /// Returns the first day of the month for a particular section.
  public func monthForSection(_ section: Int) -> Date {
    return calendar.date(byAdding: .month, value: section, to: startDate)!
  }

  /// The date associated with an index path in the data source.
  public func dateForIndexPath(_ indexPath: IndexPath) -> Date {
    let startOfMonth = monthForSection(indexPath.section)
    let daysPastStartOfMonth = indexPath.row
    return calendar.date(
      byAdding: .day,
      value: daysPastStartOfMonth,
      to: startOfMonth
    )!
  }

  /// Returns the number of days in a given month.
  public func numberOfDays(in section: Int) -> Int {
    return calendar.range(of: .day, in: .month, for: monthForSection(section))!.count
  }
}

/// A UICollectionView layout that can be applied to collection views that contain
/// one item per day and one section per month.
public final class CalendarLayout: UICollectionViewLayout, LayoutTargetContentOffsetDescribing {
  public enum SupplementaryViewKind: String {
    case monthHeader = "UICollectionElementKindSectionHeader"
  }

  /// Set this to the desired height of the month header.
  public var monthHeaderHeight: CGFloat = 0 {
    didSet {
      invalidateLayout()
    }
  }

  var cellWidth: CGFloat = 0.0
  var countOfMonths: Int = 0
  var countOfWeekdays: Int = 0
  var endDate: Date!
  var lastQueriedAttributes: UICollectionViewLayoutAttributes?
  var monthHeaderCache: [UICollectionViewLayoutAttributes] = []
  /// The starting Y position for each month (including month header)
  var monthOffsets: [CGFloat] = []
  var oldBounds: CGRect?
  var startDate: Date!
  public var targetContentOffset: CGPoint?

  var indexPathToAttributesCache: NSCache<AnyObject, AnyObject>?
  var rectToAttributesCache: NSCache<AnyObject, AnyObject>?

  override public func prepare() {
    DDLogLayout("CalendarLayout.prepareLayout")
    guard let collectionView = self.collectionView else { return }
    guard let dataSource = collectionView.dataSource as? CalendarDataSource else { return }
    indexPathToAttributesCache = NSCache()
    rectToAttributesCache = NSCache()
    let calendar = dataSource.calendar
    countOfWeekdays = (calendar as NSCalendar).minimumRange(of: .weekday).length
    assert(countOfWeekdays == (calendar as NSCalendar).maximumRange(of: .weekday).length)
    cellWidth = floor(collectionView.bounds.width / CGFloat(countOfWeekdays))
    endDate = dataSource.endDate
    startDate = dataSource.startDate
    let components = calendar.dateComponents([.month], from: startDate, to: endDate)
    countOfMonths = components.month! + 1
    assert(countOfMonths == dataSource.numberOfSections?(in: collectionView) ?? 1)
    let cellEdgeLength = self.cellWidth
    monthOffsets = [0]
    monthHeaderCache = []
    for month in 0..<countOfMonths {
      let startOfMonth = calendar.date(byAdding: .month, value: month, to: startDate)!
      let weeksInMonth = calendar.range(of: .weekOfMonth, in: .month, for: startOfMonth)!.count
      let heightOfMonth = monthHeaderHeight + cellEdgeLength * CGFloat(weeksInMonth)
      monthOffsets.append(monthOffsets.last! + heightOfMonth)
      if monthHeaderHeight > 0 {
        monthHeaderCache.append(
          layoutAttributesForSupplementaryView(
            ofKind: SupplementaryViewKind.monthHeader.rawValue,
            at: IndexPath(item: 0, section: month)
            )!
        )
      }
    }
  }

  override public func prepareForTransition(to newLayout: UICollectionViewLayout) {
    DDLogLayout("CalendarLayout.prepareForTransitionToLayout")
    oldBounds = self.collectionView?.bounds
  }

  override public func prepareForTransition(from oldLayout: UICollectionViewLayout) {
    DDLogLayout("CalendarLayout.prepareForTransitionFromLayout \(oldLayout)")
  }

  override public func finalizeLayoutTransition() {
    DDLogLayout("CalendarLayout finalizeLayoutTransition")
    targetContentOffset = nil
  }

  override public func targetContentOffset(
    forProposedContentOffset proposedContentOffset: CGPoint
  ) -> CGPoint {
    DDLogLayout("CalendarLayout.targetContentOffset \(proposedContentOffset)")

    // Try to go to the last visible bounds in this layout if it makes sense.
    // `lastQueriedAttributes` should be the cell that we want to ensure is in the view.
    if oldBounds == nil || lastQueriedAttributes == nil {
      targetContentOffset = proposedContentOffset
    } else {
      let proposedBounds = CGRect(origin: proposedContentOffset, size: oldBounds!.size)
      if proposedBounds.contains(lastQueriedAttributes!.frame)
        && oldBounds!.contains(lastQueriedAttributes!.frame) {
        targetContentOffset = oldBounds!.origin
      } else {
        targetContentOffset = proposedContentOffset
      }
    }
    return targetContentOffset!
  }

  override public var collectionViewContentSize: CGSize {
    DDLogLayout("CalendarLayout.collectionViewContentSize")
    guard let lastMonthHeight = monthOffsets.last else { return CGSize.zero }
    return CGSize(width: self.collectionView!.bounds.width, height: lastMonthHeight)
  }

  override public func layoutAttributesForElements(
    in rect: CGRect
  ) -> [UICollectionViewLayoutAttributes]? {
    let box = NSValue(cgRect: rect)
    if let cachedResults = rectToAttributesCache?.object(forKey: box) {
      return cachedResults as? [UICollectionViewLayoutAttributes]
    }
    DDLogLayout("CalendarLayout.layoutAttributesForElementsInRect \(rect)")
    // Current strategy is to determine what months overlap `rect`, and return the layout attributes
    // for all of the items
    guard let dataSource = collectionView?.dataSource as? CalendarDataSource else { return nil }
    let calendar = dataSource.calendar
    let minY = rect.minY
    let maxY = rect.maxY
    var i = 0
    // Find the first month that starts after minY, then you've gone 1 too far.
    while i < monthOffsets.count && monthOffsets[i] <= minY {
      i += 1
    }
    let minSection = max(0, i-1)
    // Find the first month that starts after maxX,
    // and you know where to stop generating attributes.
    while i < monthOffsets.count && maxY > monthOffsets[i] {
      i += 1
    }
    let maxSection = min(i, dataSource.numberOfSections?(in: collectionView!) ?? 1)

    var layoutAttributesArray: [UICollectionViewLayoutAttributes] = []
    for section in minSection ..< maxSection {
      let startOfMonth = calendar.date(byAdding: .month, value: section, to: startDate)!
      let daysInSection = calendar.range(of: .day, in: .month, for: startOfMonth)!.count
      for day in 0 ..< daysInSection {
        let indexPath = IndexPath(item: day, section: section)
        if let layoutAttributes = _layoutAttributesForIndexPath(indexPath) {
          layoutAttributesArray.append(layoutAttributes)
        } else {
          assertionFailure("Expected layoutAttributes for a valid date: \(startOfMonth) + \(day)")
        }
      }
    }
    for headerAttributes in monthHeaderCache {
      if headerAttributes.frame.intersects(rect) {
        layoutAttributesArray.append(headerAttributes)
      }
    }
    rectToAttributesCache?.setObject(layoutAttributesArray as AnyObject, forKey: box)
    return layoutAttributesArray
  }

  override public func layoutAttributesForItem(
    at indexPath: IndexPath
  ) -> UICollectionViewLayoutAttributes? {
    let attributes = _layoutAttributesForIndexPath(indexPath)
    lastQueriedAttributes = attributes
    DDLogLayout("CalendarLayout.layoutAttributes \(indexPath): \(String(describing: attributes))")
    return attributes
  }

  private func _layoutAttributesForIndexPath(
    _ indexPath: IndexPath
  ) -> UICollectionViewLayoutAttributes? {
    if let cachedResult = indexPathToAttributesCache?.object(forKey: indexPath as AnyObject) {
      return cachedResult as? UICollectionViewLayoutAttributes
    }
    guard let dataSource = collectionView?.dataSource as? CalendarDataSource else { return nil }
    let calendar = dataSource.calendar
    let date = dataSource.dateForIndexPath(indexPath)
    let monthDelta = calendar.dateComponents(
      [.month],
      from: dataSource.startDate,
      to: date
      ).month!
    let yOffset = monthOffsets[monthDelta]
    let weekOfMonth = (calendar as NSCalendar).component(.weekOfMonth, from: date)
    let dayOfWeek = (calendar as NSCalendar).component(.weekday, from: date)

    let layoutAttributes = UICollectionViewLayoutAttributes.init(forCellWith: indexPath)
    layoutAttributes.frame = CGRect(
      x: CGFloat(dayOfWeek-1) * cellWidth,
      y: yOffset + monthHeaderHeight + CGFloat(weekOfMonth-1)*cellWidth,
      width: cellWidth,
      height: cellWidth
    )
    layoutAttributes.zIndex = zIndexForIndexPath(indexPath)
    indexPathToAttributesCache?.setObject(layoutAttributes, forKey: indexPath as AnyObject)
    return layoutAttributes
  }

  fileprivate func zIndexForIndexPath(_ indexPath: IndexPath) -> Int {
    return self.collectionView?.indexPathsForSelectedItems?.index(of: indexPath) ?? -10
  }

  override public func layoutAttributesForSupplementaryView(
    ofKind elementKind: String,
    at indexPath: IndexPath
  ) -> UICollectionViewLayoutAttributes? {
    if monthHeaderHeight == 0.0 { return nil }
    guard let collectionView = self.collectionView else { return nil }
    guard let enumValue = SupplementaryViewKind(rawValue: elementKind) else { return nil }
    switch enumValue {
    case .monthHeader:
      let yOffset = monthOffsets[(indexPath as NSIndexPath).section]
      let frame = CGRect(
        x: 0,
        y: yOffset,
        width: collectionView.frame.size.width,
        height: monthHeaderHeight
      )
      let layoutAttributes = UICollectionViewLayoutAttributes(
        forSupplementaryViewOfKind: elementKind,
        with: indexPath
      )
      layoutAttributes.frame = frame
      layoutAttributes.zIndex = -10
      return layoutAttributes
    }
  }

  override public func layoutAttributesForDecorationView(
    ofKind elementKind: String,
    at indexPath: IndexPath
  ) -> UICollectionViewLayoutAttributes? {
    return nil
  }
}
