// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import TextBundleKit
import UIKit

public final class ChallengesViewController: UIViewController {

  public init(storage: StudyStatisticsStorageContaining) {
    self.statisticsStorage = storage.studyStatisticsStorage
    super.init(nibName: nil, bundle: nil)
    subscription = statisticsStorage.statistics.subscribe { [weak self](result) in
      switch result {
      case .success(let statistics):
        self?.processStatistics(statistics.value)
      case .failure:
        // TODO: write an error state view
        self?.dataSource.challenges = []
      }
    }
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let statisticsStorage: StudyStatisticsStorage
  private var subscription: AnySubscription!

  private let layout: UICollectionViewFlowLayout = {
    let layout = UICollectionViewFlowLayout()
    layout.scrollDirection = .vertical
    layout.estimatedItemSize = CGSize(width: 5, height: 5)
    return layout
  }()

  private let dataSource = ChallengesDataSource()

  private lazy var collectionView: UICollectionView = {
    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    collectionView.backgroundColor = Stylesheet.hablaEspanol.darkSurface
    collectionView.dataSource = dataSource
    collectionView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
    dataSource.collectionView = collectionView
    return collectionView
  }()

  public override func loadView() {
    self.view = collectionView
  }

  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    dataSource.cellWidth = collectionView.bounds.width - 32
  }

  private let streakChallenges: [StreakChallengeDescription] = [
    StreakChallengeDescription(
      days: 7,
      caption: "Good dog!",
      trophyURL: URL(string: "https://media.giphy.com/media/1Ju5mGZlWAqek/giphy.gif")!
    ),
    StreakChallengeDescription(
      days: 14,
      caption: "Even cooler than a skating dog.",
      trophyURL: URL(string: "https://media.giphy.com/media/ngzhAbaGP1ovS/giphy.gif")!
    ),
    StreakChallengeDescription(
      days: 30,
      caption: "That's amazing!",
      trophyURL: URL(string: "https://media.giphy.com/media/5p2wQFyu8GsFO/giphy.gif")!
    ),
  ]

  private func processStatistics(_ statistics: [StudySession.Statistics]) {
    let studyDates = statistics
      .map { Calendar.current.startOfDay(for: $0.startDate) }
      .sorted()
    let streaks = StreakArray(dates: studyDates)
    dataSource.challenges = challenges(from: streaks)
  }

  private let formatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .full
    return formatter
  }()

  private func challenges(from streaks: StreakArray) -> [ChallengesDataSource.Challenge] {
    var challenges: [ChallengesDataSource.Challenge] = []
    for challengeDescription in streakChallenges {
      let title = "Study \(challengeDescription.days) days in a row"
      if let achievementDate = streaks.dateAchievedStreak(length: challengeDescription.days) {
        let body = "Achievement unlocked: \(formatter.string(from: achievementDate))"
        let challenge = ChallengesDataSource.Challenge(
          title: title,
          body: body,
          caption: challengeDescription.caption,
          trophyURL: challengeDescription.trophyURL,
          achieved: true
        )
        challenges.append(challenge)
      } else {
        let body = [streaks.currentStreakFragment, streaks.bestStreakFragment].joined()
        let challenge = ChallengesDataSource.Challenge(
          title: title,
          body: body.isEmpty ? "Keep studying!" : body,
          caption: challengeDescription.caption,
          trophyURL: challengeDescription.trophyURL,
          achieved: false
        )
        challenges.append(challenge)
        break
      }
    }
    return challenges.reversed()
  }
}

extension ChallengesViewController: UIScrollViewForTracking {
  public var scrollViewForTracking: UIScrollView {
    return collectionView
  }
}

extension ChallengesViewController {
  private struct StreakChallengeDescription {
    let days: Int
    let caption: String
    let trophyURL: URL
  }

  private struct StreakArray {
    init(dates: [Date]) {
      var streaks: [ClosedRange<Date>] = []
      var maxStreak = 0
      for date in dates {
        let range = date ... date.addingTimeInterval(TimeInterval.day)
        if let updatedLastRange = streaks.last?.combining(with: range) {
          _ = streaks.popLast()
          streaks.append(updatedLastRange)
          maxStreak = max(maxStreak, updatedLastRange.daysInRange)
        } else {
          streaks.append(range)
          maxStreak = max(maxStreak, range.daysInRange)
        }
      }
      self.streaks = streaks
      self.maxStreak = maxStreak
    }
    let streaks: [ClosedRange<Date>]
    let maxStreak: Int

    func dateAchievedStreak(length: Int) -> Date? {
      guard let streak = streaks.first(where: { $0.daysInRange >= length }) else { return nil }
      return Calendar.current.date(
        byAdding: .day,
        value: length - 1,
        to: streak.lowerBound
      )
    }

    var currentStreakFragment: String {
      guard let currentStreak = streaks.last,
            currentStreak.contains(Calendar.current.startOfDay(for: Date())) else {
        return ""
      }
      let days = currentStreak.daysInRange
      return days == 1 ? "Current streak: 1 day. " : "Current streak: \(days) days. "
    }

    var bestStreakFragment: String {
      if maxStreak == 0 { return "" }
      return maxStreak == 1 ? "Best streak: 1 day. " : "Best streak: \(maxStreak) days. "
    }
  }
}
