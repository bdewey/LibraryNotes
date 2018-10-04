// Copyright © 2018 Brian's Brain. All rights reserved.

import UIKit

import CommonplaceBook
import DZNPhotoPickerController
import MaterialComponents
import SDWebImage
import SnapKit
import TextBundleKit

protocol NewVocabularyAssociationViewControllerDelegate: class {
  func newVocabularyAssociation(
    _ viewController: NewVocabularyAssociationViewController,
    didAddVocabularyAssocation: VocabularyAssociation
  )

  func newVocabularyAssociationDidCancel(_ viewController: NewVocabularyAssociationViewController)
}

extension Optional where Wrapped: Collection {
  var isEmpty: Bool {
    switch self {
    case .none:
      return true
    case .some(let wrapped):
      return wrapped.isEmpty
    }
  }
}

final class NewVocabularyAssociationViewController: UIViewController {

  init(
    vocabularyAssociation: VocabularyAssociation?,
    delegate: NewVocabularyAssociationViewControllerDelegate
  ) {
    registerBingImageSearch
    self.initialVocabularyAssociation = vocabularyAssociation
    self.delegate = delegate
    super.init(nibName: nil, bundle: nil)
    addChild(appBar.headerViewController)
    title = "¡Habla Español!"
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  private weak var delegate: NewVocabularyAssociationViewControllerDelegate?
  private let initialVocabularyAssociation: VocabularyAssociation?

  private let appBar: MDCAppBar = {
    let appBar = MDCAppBar()
    MDCAppBarColorThemer.applySemanticColorScheme(Stylesheet.hablaEspanol.colorScheme, to: appBar)
    MDCAppBarTypographyThemer.applyTypographyScheme(Stylesheet.hablaEspanol.typographyScheme, to: appBar)
    return appBar
  }()

  private lazy var spanishTextField: TextFieldAndController = {
    let tfac = TextFieldAndController(placeholder: "Spanish", stylesheet: Stylesheet.hablaEspanol)
    tfac.field.autocapitalizationType = .none
    tfac.field.autocorrectionType = .no
    tfac.field.delegate = self
    tfac.field.trailingView = translateSpanishToEnglishButton
    tfac.field.trailingViewMode = .whileEditing
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(textDidChange),
      name: UITextField.textDidChangeNotification,
      object: tfac.field
    )
    return tfac
  }()

  private lazy var englishTextField: TextFieldAndController = {
    let tfac = TextFieldAndController(placeholder: "English", stylesheet: Stylesheet.hablaEspanol)
    tfac.field.autocapitalizationType = .none
    tfac.field.autocorrectionType = .no
    tfac.field.delegate = self
    tfac.field.trailingView = translateEnglishToSpanishButton
    tfac.field.trailingViewMode = .whileEditing
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(textDidChange),
      name: UITextField.textDidChangeNotification,
      object: tfac.field
    )
    return tfac
  }()

  private lazy var translateSpanishToEnglishButton: UIButton = {
    let translateButton = UIButton(type: .custom)
    translateButton.setImage(
      UIImage(named: "translate", in: ResourceBundle.bundle, compatibleWith: nil),
      for: .normal
    )
    translateButton.addTarget(self, action: #selector(didTapTranslateSpanishToEnglish(button:)), for: .touchUpInside)
    translateButton.sizeToFit()
    return translateButton
  }()

  private lazy var translateEnglishToSpanishButton: UIButton = {
    let translateButton = UIButton(type: .custom)
    translateButton.setImage(
      UIImage(named: "translate", in: ResourceBundle.bundle, compatibleWith: nil),
      for: .normal
    )
    translateButton.addTarget(self, action: #selector(didTapTranslateEnglishToSpanish(button:)), for: .touchUpInside)
    translateButton.sizeToFit()
    return translateButton
  }()

  private lazy var imageSearchButton: MDCButton = {
    let button = MDCButton(frame: .zero)
    MDCTextButtonThemer.applyScheme(Stylesheet.hablaEspanol.buttonScheme, to: button)
    button.setTitle("Add Image", for: .normal)
    button.addTarget(self, action: #selector(didTapImageSearch), for: .touchUpInside)
    return button
  }()

  private lazy var removeImageButton: MDCButton = {
    let button = MDCButton(frame: .zero)
    MDCTextButtonThemer.applyScheme(Stylesheet.hablaEspanol.buttonScheme, to: button)
    button.setTitle("Remove Image", for: .normal)
    button.addTarget(self, action: #selector(didTapRemoveImage), for: .touchUpInside)
    return button
  }()

  private lazy var imageView: UIImageView = {
    let imageView = UIImageView(frame: .zero)
    imageView.contentMode = .scaleAspectFit
    return imageView
  }()

  private lazy var spellingSwitch: UISwitch = {
    let spellingSwitch = UISwitch()
    return spellingSwitch
  }()

  private lazy var spellingRow: UIStackView = {
    let label = UILabel(frame: .zero)
    label.text = "Quiz spelling?"
    label.font = Stylesheet.hablaEspanol.typographyScheme.body1

    let stack = UIStackView(arrangedSubviews: [spellingSwitch, label])
    stack.axis = .horizontal
    stack.spacing = 8
    return stack
  }()

  private lazy var doneButton: UIBarButtonItem = {
    return UIBarButtonItem(title: "DONE", style: .plain, target: self, action: #selector(didTapDone))
  }()

  override func loadView() {
    let view = UIView(frame: .zero)
    view.backgroundColor = Stylesheet.hablaEspanol.colorScheme.backgroundColor
    self.view = view
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    let buttonStack = UIStackView(arrangedSubviews: [imageSearchButton, removeImageButton])
    let stack = UIStackView(
      arrangedSubviews: [
        spanishTextField.field,
        englishTextField.field,
        spellingRow,
        buttonStack,
        imageView,
      ])
    stack.axis = .vertical
    view.addSubview(stack)
    stack.snp.makeConstraints { (make) in
      make.top.equalTo(view.safeAreaLayoutGuide.snp.topMargin).offset(16)
      make.left.equalToSuperview().offset(16)
      make.right.equalToSuperview().offset(-16)
    }
    imageView.snp.makeConstraints { (make) in
      make.width.equalTo(200)
      make.height.equalTo(200)
    }

    appBar.addSubviewsToParent()
    appBar.navigationBar.trailingBarButtonItem = doneButton
    appBar.navigationBar.leadingBarButtonItem = UIBarButtonItem(title: "CANCEL", style: .plain, target: self, action: #selector(didTapCancel))
    appBar.headerViewController.topLayoutGuideViewController = self
    appBar.headerViewController.isTopLayoutGuideAdjustmentEnabled = true
    spanishTextField.field.becomeFirstResponder()

    spanishTextField.field.text = initialVocabularyAssociation?.spanish
    englishTextField.field.text = initialVocabularyAssociation?.english.word
    imageView.image = initialVocabularyAssociation?.english.image
    spellingSwitch.isOn = initialVocabularyAssociation?.testSpelling ?? false

    configureUI()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
  }

  private func configureUI() {
    doneButton.isEnabled = !spanishTextField.field.text.isEmpty
      && (!englishTextField.field.text.isEmpty || imageView.image != nil)
    translateSpanishToEnglishButton.isEnabled = !spanishTextField.field.text.isEmpty
    translateEnglishToSpanishButton.isEnabled = !englishTextField.field.text.isEmpty
    imageSearchButton.isEnabled = !spanishTextField.field.text.isEmpty
    imageSearchButton.isHidden = imageView.image != nil
    removeImageButton.isHidden = imageView.image == nil
  }

  @objc private func textDidChange() {
    configureUI()
  }

  @objc private func didTapCancel() {
    delegate?.newVocabularyAssociationDidCancel(self)
  }

  private func englishWordOrImage() -> WordOrImage {
    if let image = imageView.image {
      return WordOrImage.image(caption: englishTextField.field.text ?? "", image: TextBundleImage(image: image, key: nil))
    } else {
      return .word(englishTextField.field.text ?? "")
    }
  }

  @objc private func didTapDone() {
    let association = VocabularyAssociation(
      spanish: spanishTextField.field.text ?? "",
      wordOrImage: englishWordOrImage(),
      testSpelling: spellingSwitch.isOn
    )
    delegate?.newVocabularyAssociation(self, didAddVocabularyAssocation: association)
  }

  private let translationService = BingTranslation()

  @objc private func didTapTranslateSpanishToEnglish(button: UIButton) {
    guard let phrase = spanishTextField.field.text, !phrase.isEmpty else { return }
    translationService.requestTranslation(of: phrase, from: .spanish, to: .english) { (result) in
      if let translation = result.value {
        self.englishTextField.field.text = translation
        self.configureUI()
      }
    }
  }

  @objc private func didTapTranslateEnglishToSpanish(button: UIButton) {
    guard let phrase = englishTextField.field.text, !phrase.isEmpty else { return }
    translationService.requestTranslation(of: phrase, from: .english, to: .spanish) { (result) in
      if let translation = result.value {
        self.spanishTextField.field.text = translation
        self.configureUI()
      }
    }
  }

  @objc private func didTapImageSearch() {
    guard let phrase = spanishTextField.field.text else { return }
    let vc = DZNPhotoPickerController()
    vc.supportedServices = DZNPhotoPickerControllerServices.serviceBingImages
    vc.initialSearchTerm = phrase
    vc.allowsEditing = false
    vc.enablePhotoDownload = false
    vc.delegate = self
    vc.modalPresentationStyle = .popover
    vc.popoverPresentationController?.sourceView = imageSearchButton
    vc.popoverPresentationController?.sourceRect = imageSearchButton.titleLabel!.frame
    vc.popoverPresentationController?.permittedArrowDirections = [.up, .down]
    present(vc, animated: true, completion: nil)
  }

  @objc private func didTapRemoveImage() {
    imageView.image = nil
    configureUI()
  }
}

extension NewVocabularyAssociationViewController: UINavigationControllerDelegate {

}

extension NewVocabularyAssociationViewController: DZNPhotoPickerControllerDelegate {
  func photoPickerController(
    _ picker: DZNPhotoPickerController!,
    didFinishPickingPhotoWithInfo userInfo: [AnyHashable: Any]!
  ) {
    let attributes = userInfo[DZNPhotoPickerControllerPhotoMetadata] as? NSDictionary
    if let thumbnailURL = attributes?["thumb_url"] as? URL {
      SDWebImageDownloader.shared().downloadImage(with: thumbnailURL, options: [], progress: nil, completed: { (image, _, _, _) in
        DispatchQueue.main.async {
          self.imageView.image = image
          self.configureUI()
        }
      })
    }
    picker.dismiss(animated: true, completion: nil)
  }

  func photoPickerController(_ picker: DZNPhotoPickerController!, didFailedPickingPhotoWithError error: Error!) {
    picker.dismiss(animated: true, completion: nil)
  }

  func photoPickerControllerDidCancel(_ picker: DZNPhotoPickerController!) {
    picker.dismiss(animated: true, completion: nil)
  }
}

extension NewVocabularyAssociationViewController: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    if textField == spanishTextField.field {
      englishTextField.field.becomeFirstResponder()
    } else {
      didTapDone()
    }
    return true
  }
}

private let registerBingImageSearch: Void = {
  DZNPhotoPickerController.registerFreeService(
    DZNPhotoPickerControllerServices.serviceBingImages,
    consumerKey: "e597b057bd4347deb1c2652ae110ae8f",
    consumerSecret: "ba52bae1ee404a2ea46cd65a8b941eae"
  )
}()
