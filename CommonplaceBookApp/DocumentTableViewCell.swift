// Copyright © 2017-present Brian's Brain. All rights reserved.

import Combine
import SnapKit
import UIKit

final class DocumentTableViewCell: UITableViewCell {
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)

    let verticalStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
    verticalStack.axis = .vertical
    verticalStack.alignment = .leading
    titleLabel.numberOfLines = 0

    let horizontalStack = UIStackView(arrangedSubviews: [ageLabel, verticalStack])
    horizontalStack.alignment = .center

    contentView.addSubview(horizontalStack)
    contentView.addSubview(divider)
    horizontalStack.snp.makeConstraints { make in
      make.edges.equalToSuperview().inset(8)
      make.height.greaterThanOrEqualTo(72)
    }
    ageLabel.snp.makeConstraints { make in
      make.width.equalTo(56)
    }
    divider.snp.makeConstraints { make in
      make.height.equalTo(1)
      make.width.equalTo(verticalStack.snp.width)
      make.bottom.equalToSuperview()
      make.right.equalToSuperview().inset(8)
    }

    backgroundColor = UIColor.systemBackground
    divider.backgroundColor = UIColor.separator

    timestampUpdatingPipeline = Just(Date())
      .merge(with: Timer.publish(every: .minute, on: .main, in: .common).autoconnect())
      .combineLatest(documentModifiedTimestampSubject)
      .sink { [weak self] currentTime, modifiedTime in
        self?.updateAgeLabel(currentTime: currentTime, modifiedTime: modifiedTime)
      }
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  var documentModifiedTimestamp: Date? {
    get { documentModifiedTimestampSubject.value }
    set { documentModifiedTimestampSubject.value = newValue }
  }

  let titleLabel = UILabel(frame: .zero)
  let detailLabel = UILabel(frame: .zero)

  private var timestampUpdatingPipeline: AnyCancellable?
  private let ageLabel = UILabel(frame: .zero)

  private let divider = UIView(frame: .zero)
  private var documentModifiedTimestampSubject = CurrentValueSubject<Date?, Never>(nil)

  private func updateAgeLabel(currentTime: Date, modifiedTime: Date?) {
    guard let modifiedTime = modifiedTime else {
      ageLabel.text = ""
      return
    }
    let dateDelta = currentTime.timeIntervalSince(modifiedTime)
    ageLabel.attributedText = NSAttributedString(
      string: DateComponentsFormatter.age.string(from: dateDelta) ?? "",
      attributes: [
        .font: UIFont.preferredFont(forTextStyle: .caption1),
        .foregroundColor: UIColor.secondaryLabel,
      ]
    )
    setNeedsLayout()
  }
}
