// Copyright (c) 2018-2025  Brian Dewey. Covered by the Apache 2.0 license.

import LibraryNotesCore
import AVFoundation
import UIKit

public final class CameraCaptureView: UIView {
  override public class var layerClass: AnyClass {
    AVCaptureVideoPreviewLayer.self
  }

  var videoPreviewLayer: AVCaptureVideoPreviewLayer {
    guard let layer = layer as? AVCaptureVideoPreviewLayer else {
      fatalError("Expected `AVCaptureVideoPreviewLayer` type for layer. Check PreviewView.layerClass implementation.")
    }

    return layer
  }

  public var session: AVCaptureSession? {
    get {
      videoPreviewLayer.session
    }

    set {
      videoPreviewLayer.session = newValue
    }
  }
}
