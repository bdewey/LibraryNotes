// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation
import MaterialComponents

/// Wraps an MDCTextField and its associated MDCTextInputController.
public struct TextFieldAndController {
  public let field: MDCTextField
  public let controller: MDCTextInputController

  public init(field: MDCTextField, controller: MDCTextInputController) {
    self.field = field
    self.controller = controller
  }

  /// Convenience initializer that creates a new MDCTextField and MDCTextInputController,
  /// also applying the default styling.
  ///
  /// - parameter placeholder: The placeholder string for the text field.
  public init(placeholder: String, stylesheet: Stylesheet) {
    let field = MDCTextField(frame: .zero)
    field.placeholder = placeholder
    let controller = MDCTextInputControllerOutlined(textInput: field)
    MDCOutlinedTextFieldColorThemer.applySemanticColorScheme(stylesheet.colorScheme, to: controller)
    MDCTextFieldTypographyThemer.applyTypographyScheme(stylesheet.typographyScheme, to: controller)
    MDCTextFieldTypographyThemer.applyTypographyScheme(stylesheet.typographyScheme, to: field)
    self.init(field: field, controller: controller)
  }
}
