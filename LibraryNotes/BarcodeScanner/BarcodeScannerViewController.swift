// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

@preconcurrency import AVFoundation
import Combine
import Logging
import SwiftUI
import UIKit

private extension Logger {
  @MainActor
  static let barcodeScanner: Logger = {
    var logger = Logger(label: "org.brians-brain.BarcodeScanner")
    logger.logLevel = .info
    return logger
  }()
}

@MainActor
public protocol BarcodeScannerViewControllerDelegate: AnyObject {
  func barcodeScannerViewController(_ viewController: BarcodeScannerViewController, didUpdateRecognizedBarcodes barcodes: Set<String>)
}

public final class BarcodeScannerViewController: UIViewController {
  private lazy var cameraCaptureView: CameraCaptureView = {
    let view = CameraCaptureView(frame: .zero)
    view.videoPreviewLayer.videoGravity = .resizeAspectFill
    return view
  }()

  private lazy var captureSessionManager = CaptureSessionManager()

  public private(set) var recognizedBarcodes = Set<String>()
  weak var delegate: BarcodeScannerViewControllerDelegate?

  private func insertBarcode(_ barcode: String) {
    if !recognizedBarcodes.contains(barcode) {
      recognizedBarcodes.insert(barcode)
      delegate?.barcodeScannerViewController(self, didUpdateRecognizedBarcodes: recognizedBarcodes)
    }
  }

  override public func loadView() {
    view = cameraCaptureView
  }

  private var startScanningTask: Task<Bool, Error>?

  public func startScanning() async throws -> Bool {
    if let startScanningTask {
      return try await startScanningTask.value
    }
    let startScanningTask = Task { () throws -> Bool in
      let hasPermission = await checkCapturePermission()
      if !hasPermission {
        showPermissionAlert()
        return false
      }
      cameraCaptureView.session = captureSessionManager.session
      try await captureSessionManager.configureSession(metadataDelegate: self, metadataQueue: .main)
      await captureSessionManager.startRunning()
      updateSessionOrientation()
      return true
    }
    self.startScanningTask = startScanningTask
    return try await startScanningTask.value
  }

  override public func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    updateSessionOrientation()
  }

  @MainActor
  private func updateSessionOrientation() {
    let deviceOrientation = UIDevice.current.orientation
    let videoOrientation = AVCaptureVideoOrientation(deviceOrientation)
    Logger.barcodeScanner.debug("Device orientation = \(deviceOrientation), video orientation = \(videoOrientation)")
    cameraCaptureView.session?.connections.first?.videoOrientation = videoOrientation
  }

  private func checkCapturePermission() async -> Bool {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .notDetermined:
      return await AVCaptureDevice.requestAccess(for: .video)
    case .denied, .restricted:
      return false
    case .authorized:
      return true
    @unknown default:
      return false
    }
  }

  private func showPermissionAlert() {
    let alert = UIAlertController(
      title: "You need to give camera permission",
      message: "We need camera permission to go further",
      preferredStyle: .alert
    )
    let okButton = UIAlertAction(title: "OK", style: .default)
    alert.addAction(okButton)
    present(alert, animated: true, completion: nil)
  }
}

extension BarcodeScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
  nonisolated public func metadataOutput(
    _ output: AVCaptureMetadataOutput,
    didOutput metadataObjects: [AVMetadataObject],
    from connection: AVCaptureConnection
  ) {
    let barcodes = metadataObjects.compactMap { metadataObject -> String? in
      guard
        let barcodeObject = metadataObject as? AVMetadataMachineReadableCodeObject,
        let barcode = barcodeObject.stringValue
      else {
        return nil
      }
      return barcode
    }
    Task { @MainActor in
      for barcode in barcodes {
        insertBarcode(barcode)
      }
    }
  }
}

extension AVCaptureVideoOrientation: CustomStringConvertible {
  // Note per Apple docs, "device orientation" and "interface orientation" flip the landscape values
  fileprivate init(_ deviceOrientation: UIDeviceOrientation) {
    switch deviceOrientation {
    case .unknown:
      self = .portrait
    case .portrait:
      self = .portrait
    case .portraitUpsideDown:
      self = .portraitUpsideDown
    case .landscapeLeft:
      self = .landscapeRight
    case .landscapeRight:
      self = .landscapeLeft
    case .faceUp:
      self = .portrait
    case .faceDown:
      self = .portrait
    @unknown default:
      self = .portrait
    }
  }

  public var description: String {
    switch self {
    case .portrait:
      return "portrait"
    case .portraitUpsideDown:
      return "portraitUpsideDown"
    case .landscapeRight:
      return "landscapeRight"
    case .landscapeLeft:
      return "landscapeLeft"
    @unknown default:
      return "unknown"
    }
  }
}

extension UIDeviceOrientation: CustomStringConvertible {
  public var description: String {
    switch self {
    case .unknown:
      return "unknown"
    case .portrait:
      return "portrait"
    case .portraitUpsideDown:
      return "portraitUpsideDown"
    case .landscapeLeft:
      return "landscapeLeft"
    case .landscapeRight:
      return "landscapeRight"
    case .faceUp:
      return "faceUp"
    case .faceDown:
      return "faceDown"
    @unknown default:
      return "unknown"
    }
  }
}
