// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Exposes UIDocumentPickerViewController for SwiftUI
struct DocumentPickerView: UIViewControllerRepresentable {
  var contentTypes: [UTType]
  var openAsCopy: Bool = true
  var action: ([URL]) -> Void

  func makeUIViewController(context: Context) -> some UIViewController {
    let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: openAsCopy)
    documentPicker.delegate = context.coordinator
    return documentPicker
  }

  func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
    // ???
  }

  func makeCoordinator() -> DocumentPickerCoordinator {
    DocumentPickerCoordinator(action: action)
  }

  final class DocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate {
    init(action: @escaping ([URL]) -> Void) {
      self.action = action
    }

    private let action: ([URL]) -> Void

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
      action(urls)
    }
  }
}

struct DocumentPickerView_Previews: PreviewProvider {
  static var previews: some View {
    DocumentPickerView(contentTypes: [.plainText]) { urls in
      print("Got URL: \(urls)")
    }
  }
}
