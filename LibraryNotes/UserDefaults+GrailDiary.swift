// Copyright © 2021 Brian's Brain. All rights reserved.

import Foundation
import Logging

extension UserDefaults {
  var immediatelySchedulePrompts: Bool {
    bool(for: "immediately_schedule_prompts", default: true)
  }

  var enableExperimentalFeatures: Bool {
    bool(for: "enable_experimental_features", default: false)
  }

  var hasRunBefore: Bool {
    get {
      bool(for: #function, default: false)
    }
    set {
      set(newValue, forKey: #function)
    }
  }

  private func bool(for key: String, default: Bool) -> Bool {
    if value(forKey: key) == nil {
      Logger.shared.info("Setting default value for \(key): \(`default`)")
      set(`default`, forKey: key)
    }
    return bool(forKey: key)
  }
}
