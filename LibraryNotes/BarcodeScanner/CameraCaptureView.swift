// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import AVFoundation
import UIKit

public final class CameraCaptureView: UIView {
  override public class var layerClass: AnyClass {
    return AVCaptureVideoPreviewLayer.self
  }

  var videoPreviewLayer: AVCaptureVideoPreviewLayer {
    guard let layer = layer as? AVCaptureVideoPreviewLayer else {
      fatalError("Expected `AVCaptureVideoPreviewLayer` type for layer. Check PreviewView.layerClass implementation.")
    }

    return layer
  }

  public var session: AVCaptureSession? {
    get {
      return videoPreviewLayer.session
    }

    set {
      videoPreviewLayer.session = newValue
    }
  }
}
