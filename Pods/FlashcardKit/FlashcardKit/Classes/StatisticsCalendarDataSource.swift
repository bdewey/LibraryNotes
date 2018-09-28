// Copyright © 2018 Brian's Brain. All rights reserved.

import CollectionViewLayouts
import CommonplaceBook
import QuartzCore
import TextBundleKit
import UIKit

extension Calendar {
  func startOfMonth(containing date: Date) -> Date {
    var components = dateComponents([.year, .month], from: date)
    components.day = 1
    return self.date(from: components)!
  }

  func endOfMonth(containing date: Date) -> Date {
    let daysInMonth = range(of: .day, in: .month, for: date)
    var components = dateComponents([.year, .month], from: date)
    components.day = daysInMonth!.count
    return self.date(from: components)!
  }
}

/// For testability, StatisticsCalendarDataSource can communicate with anything that conforms
/// to this protocol, not just UICollectionView instances.
protocol StatisticsCalendarCollectionView: class {
  func register(_ cellClass: AnyClass?, forCellWithReuseIdentifier identifier: String)
  func register(
    _ viewClass: AnyClass?,
    forSupplementaryViewOfKind elementKind: String,
    withReuseIdentifier identifier: String
  )
  func reloadData()
}

extension UICollectionView: StatisticsCalendarCollectionView { }

/// A UICollectionViewDataSource that vends calendar cells configured to show if the person
/// studied on that day.
final class StatisticsCalendarDataSource: NSObject {

  /// Initializer.
  init(studyStatistics: DocumentProperty<[StudySession.Statistics]>) {
    let today = Date()
    startDate = calendar.startOfMonth(containing: today)
    endDate = calendar.endOfMonth(containing: today)
    super.init()
    subscription = studyStatistics.subscribe { [weak self](result) in
      guard let value = result.value else { return }
      self?.processStatistics(value.value)
    }
  }

  private let reuseIdentifier = "StatisticsCalendar.DateCell"
  private let headerReuseIdentifier = "StatisticsCalendar.Header"

  /// Keeps the subscription alive.
  private var subscription: AnySubscription!

  /// The collection view the data source is bound to.
  public weak var collectionView: StatisticsCalendarCollectionView? {
    didSet {
      collectionView?.register(DateCell.self, forCellWithReuseIdentifier: reuseIdentifier)
      collectionView?.register(
        StatisticsMonthHeaderReusableView.self,
        forSupplementaryViewOfKind: CalendarLayout.SupplementaryViewKind.monthHeader.rawValue,
        withReuseIdentifier: headerReuseIdentifier
      )
    }
  }
  let calendar = Calendar.current
  var startDate: Date
  var endDate: Date
  private var currentStatistics: [StudySession.Statistics] = []
  private let happyEmojis = "😀👍🤩😻👌"

  private func processStatistics(_ statistics: [StudySession.Statistics]) {
    currentStatistics = statistics.sorted(by: { (lhs, rhs) -> Bool in
      return lhs.startDate < rhs.startDate
    })
    if let first = currentStatistics.first {
      startDate = calendar.startOfMonth(containing: first.startDate)
    } else {
      startDate = calendar.startOfMonth(containing: Date())
    }
    if let last = currentStatistics.last {
      let date = max(Date(), last.startDate)
      endDate = calendar.endOfMonth(containing: date)
    } else {
      endDate = calendar.endOfMonth(containing: Date())
    }
    collectionView?.reloadData()
  }
}

extension StatisticsCalendarDataSource: CalendarDataSource {
  func numberOfSections(in collectionView: UICollectionView) -> Int {
    return countOfMonths
  }

  func collectionView(
    _ collectionView: UICollectionView,
    numberOfItemsInSection section: Int
  ) -> Int {
    return numberOfDays(in: section)
  }

  func collectionView(
    _ collectionView: UICollectionView,
    viewForSupplementaryElementOfKind kind: String,
    at indexPath: IndexPath
  ) -> UICollectionReusableView {
    let header = collectionView.dequeueReusableSupplementaryView(
      ofKind: kind,
      withReuseIdentifier: headerReuseIdentifier,
      for: indexPath
    ) as! StatisticsMonthHeaderReusableView // swiftlint:disable:this force_cast
    header.date = monthForSection(indexPath.section)
    return header
  }

  func collectionView(
    _ collectionView: UICollectionView,
    cellForItemAt indexPath: IndexPath
  ) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: reuseIdentifier,
      for: indexPath
    ) as! DateCell // swiftlint:disable:this force_cast
    let date = dateForIndexPath(indexPath)
    let statisticsOnDate = currentStatistics.first(where: { (statistics) -> Bool in
      return calendar.startOfDay(for: statistics.startDate) == calendar.startOfDay(for: date)
    })
    if statisticsOnDate != nil {
      cell.text = String(happyEmojis.randomElement()!)
      cell.isEmpty = false
    } else {
      cell.text = DateFormatter.formatterWithDay.string(from: date)
      cell.isEmpty = true
    }
    cell.isToday = (calendar.startOfDay(for: Date()) == calendar.startOfDay(for: date))
    return cell
  }
}

extension StatisticsCalendarDataSource {

  /// The specific calendar cell.
  class DateCell: UICollectionViewCell {
    override init(frame: CGRect) {
      self.label = UILabel(frame: .zero)
      super.init(frame: .zero)
      label.frame = contentView.bounds
      label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      label.textAlignment = .center
      label.font = Stylesheet.hablaEspanol.typographyScheme.body2
      contentView.addSubview(label)
    }

    required init?(coder aDecoder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    private let label: UILabel

    /// True if there is nothing sigificant about this date; false if the person studied on the
    /// date.
    public var isEmpty: Bool = false

    public var isToday: Bool = false {
      didSet {
        if isToday {
          self.layer.borderColor = Stylesheet.hablaEspanol.colorScheme.primaryColor.cgColor
          self.layer.borderWidth = 1.0
          self.layer.cornerRadius = 4.0
        } else {
          self.layer.borderWidth = 0.0
        }
      }
    }

    public var text: String? {
      get {
        return label.text
      }
      set {
        label.text = newValue
      }
    }
  }
}
