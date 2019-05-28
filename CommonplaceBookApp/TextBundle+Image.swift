// Copyright © 2018-present Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown
import TextBundleKit

extension TextBundleDocument {
  func image(for node: Node) -> UIImage? {
    guard let imageNode = node as? Image else { return nil }
    let imagePath = imageNode.url.split(separator: "/").map { String($0) }
    guard let key = imageNode.url.split(separator: "/").map({ String($0) }).last,
      let data = try? data(for: key, at: Array(imagePath.dropLast())),
      let image = UIImage(data: data)
    else { return nil }
    return image
  }
}
