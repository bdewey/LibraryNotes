// Copyright © 2018 Brian's Brain. All rights reserved.

import UIKit

public typealias IdentifierToStudyMetadata = Dictionary<String, StudyMetadata>

public protocol StudyItem: Comparable {
  var tableViewTitle: NSAttributedString { get }
  func studyMetadata(from identifierToStudyMetadata: IdentifierToStudyMetadata) -> StudyMetadata
}

fileprivate let dateFormatter: DateFormatter = {
  let dateFormatter = DateFormatter()
  dateFormatter.dateStyle = .short
  dateFormatter.doesRelativeDateFormatting = true
  return dateFormatter
}()

public final class StudyMetadataDataSource<Item: StudyItem>: NSObject, UITableViewDataSource {
  private let reuseIdentifier = "StudyMetadataDataSource"

  private struct ItemData: Comparable {
    let item: Item
    let studyMetadata: StudyMetadata

    static func < (
      lhs: StudyMetadataDataSource<Item>.ItemData,
      rhs: StudyMetadataDataSource<Item>.ItemData
    ) -> Bool {
      return lhs.item < rhs.item
    }
  }

  private struct SectionData {
    let targetDate: Date
    let items: [ItemData]
  }

  private var data: [SectionData] = []

  public weak var tableView: UITableView? {
    didSet {
      tableView?.register(UITableViewCell.self, forCellReuseIdentifier: reuseIdentifier)
    }
  }

  public func update(items: [Item], studyMetadata: IdentifierToStudyMetadata) {
    let today = DayComponents(Date())
    let itemData = items.map { ItemData(item: $0, studyMetadata: $0.studyMetadata(from: studyMetadata)) }
    let daysToItemData = Dictionary(grouping: itemData) {
      return max($0.studyMetadata.dayForNextReview, today)
    }
    data = daysToItemData
      .map { SectionData(targetDate: $0.key.date, items: $0.value.sorted() ) }
      .sorted(by: { $0.targetDate < $1.targetDate })
    tableView?.reloadData()
  }

  public func item(at indexPath: IndexPath) -> Item {
    return data[indexPath.section].items[indexPath.row].item
  }

  // MARK: - UITableViewDataSource

  public func numberOfSections(in tableView: UITableView) -> Int {
    return data.count
  }

  public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    let section = data[section]
    return dateFormatter.string(from: section.targetDate)
  }

  public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return data[section].items.count
  }

  public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
    let item = self.item(at: indexPath)
    cell.textLabel?.attributedText = item.tableViewTitle
    return cell
  }
}
