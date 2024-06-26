// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

@preconcurrency import AVFoundation
import Combine
import os
import SwiftUI
import UIKit

private extension Logger {
  @MainActor
  static let barcodeScanner = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "BarcodeScanner")
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
      try await captureSessionManager.configureSession(
        metadataDelegate: self,
        metadataQueue: .main
      )
      await captureSessionManager.startRunning()
      return true
    }
    self.startScanningTask = startScanningTask
    return try await startScanningTask.value
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
  public nonisolated func metadataOutput(
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
