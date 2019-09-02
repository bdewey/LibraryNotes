// Copyright © 2019 Brian's Brain. All rights reserved.

import SwiftUI

extension View {
  func locale(_ locale: Locale) -> some View {
    self.environment(\.locale, locale)
  }
}
