// Copyright © 2017-present Brian's Brain. All rights reserved.

import SwiftUI
import UIKit

extension EnvironmentValues {
  private struct AutocapitalizationTypeKey: EnvironmentKey {
    static let defaultValue = UITextAutocapitalizationType.sentences
  }

  /// The autocapitalization type used by LocaleAwareTextField
  var autocapitalizationType: UITextAutocapitalizationType {
    get {
      return self[AutocapitalizationTypeKey.self]
    }
    set {
      self[AutocapitalizationTypeKey.self] = newValue
    }
  }
}

extension View {
  /// Sets the autocapitalizationType in the environment
  func customAutocapitalization(_ autocapitalizationType: UITextAutocapitalizationType) -> some View {
    environment(\.autocapitalizationType, autocapitalizationType)
  }
}

/// A custom replacement for TextField that will try to change the keyboard input language.
struct LocaleAwareTextField: UIViewRepresentable {
  init(
    _ title: String,
    text: Binding<String>,
    onCommit: @escaping () -> Void = {},
    shouldBeFirstResponder: Bool = false
  ) {
    self.title = title
    self._text = text
    self.onCommit = onCommit
    self.shouldBeFirstResponder = shouldBeFirstResponder
  }

  /// Placeholder text for the field
  let title: String

  /// The field text itself
  @Binding var text: String

  /// Action to take upon "return" key
  let onCommit: () -> Void

  /// Whether this field should be the first responder
  let shouldBeFirstResponder: Bool

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeUIView(context: UIViewRepresentableContext<LocaleAwareTextField>) -> UILanguageAwareTextField {
    let uiTextField = UILanguageAwareTextField(frame: .zero)
    uiTextField.delegate = context.coordinator
    uiTextField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)
    return uiTextField
  }

  func updateUIView(
    _ uiView: UILanguageAwareTextField,
    context: UIViewRepresentableContext<LocaleAwareTextField>
  ) {
    uiView.customLanguage = context.environment.locale.languageCode
    uiView.autocorrectionType = (context.environment.disableAutocorrection ?? false) ? .no : .yes
    uiView.autocapitalizationType = context.environment.autocapitalizationType
    uiView.placeholder = title
    uiView.text = text
    if shouldBeFirstResponder, !context.coordinator.isFirstResponder {
      uiView.becomeFirstResponder()
      context.coordinator.isFirstResponder = true
    } else if !shouldBeFirstResponder, context.coordinator.isFirstResponder {
      uiView.resignFirstResponder()
      context.coordinator.isFirstResponder = false
    }
  }

  final class Coordinator: NSObject, UITextFieldDelegate {
    init(_ textField: LocaleAwareTextField) {
      self.textField = textField
    }

    private var textField: LocaleAwareTextField
    var isFirstResponder = false

    @objc func textDidChange(_ uiTextField: UITextField) {
      textField.text = uiTextField.text ?? ""
    }

    func textFieldShouldReturn(_ uiTextField: UITextField) -> Bool {
      uiTextField.resignFirstResponder()
      textField.onCommit()
      return true
    }
  }
}

/// UIKit subclass of UITextField that selects an activeInputMode with a preferred language
final class UILanguageAwareTextField: UITextField {
  var customLanguage: String?

  override var textInputMode: UITextInputMode? {
    for inputMode in UITextInputMode.activeInputModes
      // swiftformat:disable:next trailingClosures
      where inputMode.primaryLanguage.map({ Locale(identifier: $0) })?.languageCode == customLanguage {
        return inputMode
      }
    return super.textInputMode
  }
}
