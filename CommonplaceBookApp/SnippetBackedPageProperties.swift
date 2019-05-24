// Copyright © 2019 Brian's Brain. All rights reserved.

import Foundation

public final class SnippetBackedPageProperties {
  public let properties: PageProperties
  public let text: TextSnippet

  init(_ text: String) {
    self.text = TextSnippet(text)
    self.properties = PageProperties(sha1Digest: self.text.sha1Digest, timestamp: Date(), hashtags: [], title: "", cardTemplates: [])
  }
}
