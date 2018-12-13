// Copyright © 2018 Brian's Brain. All rights reserved.

import CollectionViewLayouts
import CommonplaceBook
import MaterialComponents
import TextBundleKit
import UIKit

public final class StatisticsViewController: UIViewController {
  public init(studyStatistics: DocumentProperty<[StudySession.Statistics]>) {
    dataSource = StatisticsCalendarDataSource(studyStatistics: studyStatistics)
    super.init(nibName: nil, bundle: nil)
    self.title = "Calendar"
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let dataSource: StatisticsCalendarDataSource

  private lazy var collectionView: UICollectionView = {
    let layout = CalendarLayout()
    layout.monthHeaderHeight = 48
    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    collectionView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    collectionView.backgroundColor = Stylesheet.hablaEspanol.colors.surfaceColor
    collectionView.dataSource = dataSource
    dataSource.collectionView = collectionView
    return collectionView
  }()

  private lazy var closeButton: UIBarButtonItem = {
    return UIBarButtonItem(
      image: UIImage(named: "round_close_black_24pt")!.withRenderingMode(.alwaysTemplate),
      style: .plain,
      target: self,
      action: #selector(didTapClose)
    )
  }()

  @objc private func didTapClose() {
    dismiss(animated: true, completion: nil)
  }

  public override func viewDidLoad() {
    super.viewDidLoad()
    collectionView.frame = view.bounds
    view.addSubview(collectionView)
  }
}

extension StatisticsViewController: UIScrollViewForTracking {
  public var scrollViewForTracking: UIScrollView {
    return collectionView
  }
}
