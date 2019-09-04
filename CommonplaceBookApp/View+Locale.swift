// Copyright © 2017-present Brian's Brain. All rights reserved.

import SwiftUI

extension View {
  func locale(_ locale: Locale) -> some View {
    environment(\.locale, locale)
  }
}
