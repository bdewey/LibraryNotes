// Copyright © 2018 Brian's Brain. All rights reserved.

import UIKit

import AVFoundation
import CommonplaceBook
import CwlSignal
import MaterialComponents
import TextBundleKit

extension VocabularyAssociation: StudyItem {

  public var tableViewTitle: NSAttributedString {
    return NSAttributedString(
      string: spanish,
      attributes: [.font: Stylesheet.hablaEspanol.typographyScheme.body2, .kern: 0.25]
    )
  }

  public func studyMetadata(from identifierToStudyMetadata: IdentifierToStudyMetadata) -> StudyMetadata {
    let today = DayComponents(Date())
    return cards
      .map { identifierToStudyMetadata[
        $0.identifier,
        default: StudyMetadata(day: today, lastAnswers: AnswerStatistics.empty)
        ]
      }
      .min(by: { $0.dayForNextReview < $1.dayForNextReview })!
  }

  public static func < (lhs: VocabularyAssociation, rhs: VocabularyAssociation) -> Bool {
    return lhs.spanish.localizedCompare(rhs.spanish) == .orderedAscending
  }

  public static func == (lhs: VocabularyAssociation, rhs: VocabularyAssociation) -> Bool {
    return lhs.spanish.localizedCompare(rhs.spanish) == .orderedSame
  }
}

/// Displays all of the VocabularyAssociations in a table view.
/// Allows creation of new VocabularyAssocations as well as editing existing associations.
/// Also allows the student to start a study session.
public final class VocabularyViewController: UIViewController {

  public init(
    languageDeck: LanguageDeck
  ) {
    self.document = languageDeck.document
    super.init(nibName: nil, bundle: nil)
    self.title = "Vocabulary"
    subscriptions += languageDeck.studySessionSignal.subscribeValues({ [weak self](studySession) in
      self?.nextStudySession = studySession
    })
    subscriptions += document.documentStudyMetadata.signal
      .map { return $0.value }
      .combineLatest(languageDeck.vocabularyAssociationsSignal) { return ($0, $1) }
      .subscribeValues({ [weak self](tuple) in
        let (studyMetadata, vocabularyAssociations) = tuple
        self?.dataSource.update(items: vocabularyAssociations, studyMetadata: studyMetadata)
      })
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let document: TextBundleDocument
  private var editingVocabularyAssociation: VocabularyAssociation?

  private var subscriptions: [Cancellable] = []

  private let addVocabularyAssociationButton: MDCButton = {
    let icon = UIImage(named: "baseline_add_black_24pt", in: ResourceBundle.bundle, compatibleWith: nil)?.withRenderingMode(.alwaysTemplate)
    let button = MDCFloatingButton(frame: .zero)
    button.setImage(icon, for: .normal)
    MDCFloatingActionButtonThemer.applyScheme(Stylesheet.hablaEspanol.buttonScheme, to: button)
    button.addTarget(self, action: #selector(addVocabularyAssocation), for: .touchUpInside)
    return button
  }()

  private lazy var tableView: UITableView = {
    let tableView = UITableView(frame: .zero)
    tableView.dataSource = dataSource
    dataSource.tableView = tableView
    tableView.delegate = self
    tableView.backgroundColor = Stylesheet.hablaEspanol.colorScheme.backgroundColor
    tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    tableView.allowsMultipleSelection = true
    return tableView
  }()

  private var nextStudySession: StudySession? {
    didSet {
      configureUI()
    }
  }

  private lazy var studyButton: UIBarButtonItem = {
    return UIBarButtonItem(
      title: "STUDY",
      style: .plain,
      target: self,
      action: #selector(startStudySession)
    )
  }()

  private let dataSource = StudyMetadataDataSource<VocabularyAssociation>()

  public override func loadView() {
    let view = UIView(frame: .zero)
    view.addSubview(tableView)
    self.view = view
  }

  public override func viewDidLoad() {
    super.viewDidLoad()

    navigationItem.rightBarButtonItem = studyButton

    view.addSubview(addVocabularyAssociationButton)
    addVocabularyAssociationButton.snp.makeConstraints { (make) in
      make.trailing.equalToSuperview().offset(-16)
      make.bottom.equalToSuperview().offset(-16)
      make.width.equalTo(56)
      make.height.equalTo(56)
    }

    configureUI()
  }

  private func configureUI() {
    studyButton.isEnabled = (nextStudySession != nil)
  }

  @objc private func startStudySession() {
    guard let studySession = nextStudySession else { return }
    let studyVC = StudyViewController(
      studySession: studySession,
      // TODO: Don't grab this global variable
      parseableDocument: ParseableDocument(document: document, parsingRules: LanguageDeck.parsingRules),
      delegate: self
    )
    studyVC.modalTransitionStyle = .crossDissolve
    present(studyVC, animated: true, completion: nil)
  }

  @objc private func addVocabularyAssocation() {
    let newVocabularyAssociation = NewVocabularyAssociationViewController(
      vocabularyAssociation: nil,
      image: nil,
      stylesheet: Stylesheet.hablaEspanol,
      delegate: self
    )
    newVocabularyAssociation.modalTransitionStyle = .crossDissolve
    present(newVocabularyAssociation, animated: true, completion: nil)
  }
}

extension VocabularyViewController: StudyViewControllerDelegate {
  func studyViewController(
    _ studyViewController: StudyViewController,
    didFinishSession session: StudySession
  ) {
    document.documentStudyMetadata.update(with: session, on: Date())
    if let statistics = session.statistics {
      document.studyStatistics.changeValue { (array) -> [StudySession.Statistics] in
        var array = array
        array.append(statistics)
        return array
      }
    }
    dismiss(animated: true, completion: {
      let utterance = AVSpeechUtterance(
        string: "Buen trabajo Alex. Eres mucho mejor en español que tu hermano."
      )
      PersonalitySpeechSynthesizer.spanish.speak(utterance)
    })
  }

  func studyViewControllerDidCancel(_ studyViewController: StudyViewController) {
    studyViewController.dismiss(animated: true, completion: nil)
  }
}

extension VocabularyViewController: NewVocabularyAssociationViewControllerDelegate {
  func newVocabularyAssociation(
    _ viewController: NewVocabularyAssociationViewController,
    didAddVocabularyAssocation association: VocabularyAssociation,
    image: UIImage?
  ) {
    dismiss(animated: true, completion: nil)
    var association = association
    // TODO: What if this was an unchanged image (it's already in the document)?
    if let image = image,
       let data = image.pngData() {
      // TODO: Make this a meaningful ID
      let uuid = UUID().uuidString
      do {
        let key = try document.addData(
          data,
          preferredFilename: uuid + ".png",
          childDirectoryPath: ["assets"]
        )
        association.english = "![\(association.english)](\(key))"
      } catch {
        fatalError("Couldn't save image")
      }
    }
    if let editingAssociation = editingVocabularyAssociation {
      document.replaceVocabularyAssociation(editingAssociation, with: association)
      editingVocabularyAssociation = nil
    } else {
      document.appendVocabularyAssociation(association)
    }
  }

  func newVocabularyAssociationDidCancel(_ viewController: NewVocabularyAssociationViewController) {
    editingVocabularyAssociation = nil
    dismiss(animated: true, completion: nil)
  }
}

private class SectionHeaderView: UIView {

  private let label: UILabel = {
    let label = UILabel(frame: .zero)
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  override init(frame: CGRect) {
    super.init(frame: frame)
    addSubview(label)
    label.snp.makeConstraints { (make) in
      make.leading.equalToSuperview().offset(20)
      make.trailing.equalToSuperview().offset(-8)
      make.bottom.equalToSuperview().offset(-8)
    }
    backgroundColor = Stylesheet.hablaEspanol.colorScheme.backgroundColor
  }

  var text: String {
    get {
      return label.text ?? ""
    }
    set {
      label.attributedText = NSAttributedString(string: newValue.localizedUppercase, attributes: [
        .font: Stylesheet.hablaEspanol.typographyScheme.overline,
        .kern: 2.0,
        .foregroundColor: UIColor.init(white: 0, alpha: 0.6),
      ])
      setNeedsLayout()
    }
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

extension VocabularyViewController: UITableViewDelegate {

  public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    guard let string = dataSource.tableView(
      tableView,
      titleForHeaderInSection: section
      ) else { return nil }
    let label = SectionHeaderView(frame: .zero)
    label.text = string
    return label
  }

  public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return 44
  }

  public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let association = dataSource.item(at: indexPath)
    editingVocabularyAssociation = association

    // TODO: Really extract the image. This is really ugly.
    let viewController = NewVocabularyAssociationViewController(
      vocabularyAssociation: association,
      image: nil,
      stylesheet: Stylesheet.hablaEspanol,
      delegate: self
    )
    viewController.modalTransitionStyle = .crossDissolve
    present(viewController, animated: true)
  }

  public func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
    guard let cell = tableView.cellForRow(at: indexPath) else { return }
    cell.accessoryType = .none
  }
}

extension VocabularyViewController: UIScrollViewForTracking {
  public var scrollViewForTracking: UIScrollView {
    return tableView
  }
}
