// Copyright © 2017-present Brian's Brain. All rights reserved.

import SnapKit
import UIKit

protocol AddVocabularyViewControllerDelegate: AnyObject {
  func addVocabularyViewController(_ viewController: AddVocabularyViewController, didAddFront: String, back: String)
}

/// Modal view controller for adding a new vocabulary association.
final class AddVocabularyViewController: UIViewController {
  weak var delegate: AddVocabularyViewControllerDelegate?

  private lazy var doneButton: UIBarButtonItem = {
    UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(didTapDone))
  }()

  private lazy var frontTextField: UITextField = {
    let textField = UITextField(frame: .zero)
    textField.placeholder = "Front"
    textField.addTarget(self, action: #selector(updateDoneButton), for: .editingChanged)
    return textField
  }()

  private lazy var backTextField: UITextField = {
    let textField = UITextField(frame: .zero)
    textField.placeholder = "Back"
    textField.addTarget(self, action: #selector(updateDoneButton), for: .editingChanged)
    return textField
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.rightBarButtonItem = doneButton
    let stack = UIStackView(arrangedSubviews: [
      frontTextField,
      backTextField,
    ])
    stack.axis = .vertical
    view.addSubview(stack)
    stack.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
    updateDoneButton()
  }

  @objc private func updateDoneButton() {
    doneButton.isEnabled = !frontTextField.text.isEmpty && !backTextField.text.isEmpty
  }

  @objc private func didTapDone() {
    delegate?.addVocabularyViewController(self, didAddFront: frontTextField.text ?? "", back: backTextField.text ?? "")
  }
}

private extension Optional where Wrapped == String {
  var isEmpty: Bool {
    switch self {
    case .none:
      return true
    case .some(let text):
      return text.isEmpty
    }
  }
}
