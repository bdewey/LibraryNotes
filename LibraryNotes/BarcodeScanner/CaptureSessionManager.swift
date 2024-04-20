// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import AVFoundation
import Foundation

public actor CaptureSessionManager: NSObject {
  public enum Error: Swift.Error {
    case noVideoDevice
    case cannotAddVideoDevice
    case cannotAddMetadataOutput
  }

  public let session = AVCaptureSession()
  private let metadataOutput = AVCaptureMetadataOutput()

  public func configureSession(
    metadataDelegate: AVCaptureMetadataOutputObjectsDelegate? = nil,
    metadataQueue: DispatchQueue? = nil
  ) throws {
    session.beginConfiguration()
    defer {
      session.commitConfiguration()
    }
    guard let videoDevice = Self.defaultVideoDevice else {
      throw Error.noVideoDevice
    }
    let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
    guard session.canAddInput(videoDeviceInput) else { throw Error.cannotAddVideoDevice }
    session.addInput(videoDeviceInput)

    guard session.canAddOutput(metadataOutput) else { throw Error.cannotAddMetadataOutput }
    session.addOutput(metadataOutput)

    // Set this view controller as the delegate for metadata objects.
    metadataOutput.setMetadataObjectsDelegate(metadataDelegate, queue: metadataQueue)
    metadataOutput.metadataObjectTypes = [.ean13]

    /*
     Set an initial square rectangle of interest that is 100% of the view's shortest side.
     This means that the region of interest appears in the same spot regardless
     of whether the app starts in portrait or landscape.
     */
    let formatDimensions = CMVideoFormatDescriptionGetDimensions(videoDeviceInput.device.activeFormat.formatDescription)
    let rectOfInterestWidth = Double(formatDimensions.height) / Double(formatDimensions.width)
    let rectOfInterestHeight = 1.0
    let xCoordinate = (1.0 - rectOfInterestWidth) / 2.0
    let yCoordinate = (1.0 - rectOfInterestHeight) / 2.0
    let initialRectOfInterest = CGRect(x: xCoordinate, y: yCoordinate, width: rectOfInterestWidth, height: rectOfInterestHeight)
    metadataOutput.rectOfInterest = initialRectOfInterest
  }

  private var rotationObservation: NSKeyValueObservation?
  private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?

  public func startRunning() {
    session.startRunning()
    if let deviceInput = session.inputs.first as? AVCaptureDeviceInput, let connection = session.connections.first {
      let unsafeConnection = UnsafeCaptureConnection(connection)
      rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: deviceInput.device, previewLayer: connection.videoPreviewLayer)
      rotationObservation = rotationCoordinator?.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { _, change in
        if let angle = change.newValue {
          Task { @MainActor in
            unsafeConnection.videoRotationAngle = angle
          }
        }
      }
    }
  }

  static let defaultVideoDevice: AVCaptureDevice? = {
    // Choose the back wide angle camera if available, otherwise default to the front wide angle camera.
    if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
      return backCameraDevice
    } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
      // Default to the front wide angle camera if the back wide angle camera is unavailable.
      return frontCameraDevice
    } else {
      return nil
    }
  }()
}

private struct UnsafeCaptureConnection: @unchecked Sendable {
  private let _connection: AVCaptureConnection

  init(_ connection: AVCaptureConnection) {
    self._connection = connection
  }

  @MainActor var videoRotationAngle: CGFloat {
    get {
      _connection.videoRotationAngle
    }
    nonmutating set {
      _connection.videoRotationAngle = newValue
    }
  }
}
