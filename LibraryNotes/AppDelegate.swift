// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import CoreSpotlight
import FileLogging
import Logging
import UIKit

public extension Logger {
  static let shared: Logger = {
    var logger = Logger(label: "org.brians-brain.grail-diary")
    logger.logLevel = .info
    return logger
  }()
}

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
  static let didRequestOpenFileNotification = NSNotification.Name(rawValue: "org.brians-brain.didRequestOpenFile")

  var window: UIWindow?
  let useCloud = true

  public static let appName = "Library Notes"

  private enum Error: String, Swift.Error {
    case noCloud = "Not signed in to iCloud"
    case unknownFormat = "Unknown file format"
  }

  // This is here to force initialization of the PromptType, which registers the class
  // with the type name. This has to be done before deserializing any prompt collections.
  private let knownPromptTypes: [PromptType] = [
    .cloze,
    .quote,
    .questionAndAnswer,
  ]

  /// The currently open database
  var database: NoteDatabase?
  /// The top-level UISplitViewController that is showing the note contents.
  var topLevelViewController: NotebookViewController?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let factory = LogHandlerFactory()
    LoggingSystem.bootstrap(factory.logHandler(for:))

    Logger.shared.info("----- Launch application version \(UIApplication.versionString)")
    return true
  }

  internal static var isUITesting: Bool = {
    CommandLine.arguments.contains("--uitesting")
  }()
}

/// Creates log handlers. Note that since this tends to run before logging is set up, and if it fails we can't get debug information for other bugs,
/// the strategy here is to crash on unexpected errors rather than "log and try to recover."
// swiftlint:disable force_try
final class LogHandlerFactory {
  var defaultLogLevel = Logger.Level.info
  var logLevelsForLabel = [String: Logger.Level]()

  func logHandler(for label: String) -> LogHandler {
    var streamHandler = StreamLogHandler.standardError(label: label)
    streamHandler.logLevel = logLevelsForLabel[label, default: defaultLogLevel]

    return MultiplexLogHandler([
      streamHandler,
      makeFileLogHandler(label: label),
    ])
  }

  private func makeFileLogHandler(label: String) -> FileLogHandler {
    LogFileDirectory.shared.initializeCurrentLogFile()
    let handler = try! FileLogHandler(label: label, localFile: LogFileDirectory.shared.currentLogFileURL)
    handler.logLevel = logLevelsForLabel[label, default: defaultLogLevel]
    return handler
  }
}