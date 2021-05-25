// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import CoreSpotlight
import FileLogging
import Logging
import UIKit

extension UTType {
  static let grailDiary = UTType("org.brians-brain.graildiary")!
}

public extension Logger {
  static let shared: Logger = {
    var logger = Logger(label: "org.brians-brain.grail-diary")
    logger.logLevel = .debug
    return logger
  }()
}

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
  static let didRequestOpenFileNotification = NSNotification.Name(rawValue: "org.brians-brain.didRequestOpenFile")

  var window: UIWindow?
  let useCloud = true

  public static let appName = "Grail Diary"

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

  private lazy var loadingViewController: LoadingViewController = {
    let loadingViewController = LoadingViewController()
    loadingViewController.title = AppDelegate.appName
    return loadingViewController
  }()

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
    let handler = try! FileLogHandler(label: label, localFile: logFileURL)
    handler.logLevel = logLevelsForLabel[label, default: defaultLogLevel]
    return handler
  }

  /// the URL to use for **the current logging session**
  private lazy var logFileURL: URL = {
    let currentLogFileURL = logFileDirectoryURL.appendingPathComponent("grail-diary-current.log")
    if
      let existingAttributes = try? FileManager.default.attributesOfItem(atPath: currentLogFileURL.path),
      let existingSize = (existingAttributes[.size] as? Int),
      existingSize > 1024 * 1024
    {
      // Roll the log.
      let creationDate = (existingAttributes[.creationDate] as? Date) ?? Date()
      let unwantedCharacters = CharacterSet(charactersIn: "-:")
      var dateString = ISO8601DateFormatter().string(from: creationDate)
      dateString.removeAll(where: { unwantedCharacters.contains($0.unicodeScalars.first!) })
      let archiveLogFileURL = logFileDirectoryURL.appendingPathComponent("grail-diary-\(dateString).log")
      try! FileManager.default.moveItem(at: currentLogFileURL, to: archiveLogFileURL)
    }
    return currentLogFileURL
  }()

  /// The container directory for all of our log files.
  private lazy var logFileDirectoryURL: URL = {
    // Right now, put the logs into the Documents directory so they're easy to find.
    let documentsDirectoryURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let logDirectoryURL = documentsDirectoryURL.appendingPathComponent("logs")
    // Try to create the "logs" subdirectory if it does not exist.
    try? FileManager.default.createDirectory(at: logDirectoryURL, withIntermediateDirectories: false, attributes: nil)
    return logDirectoryURL
  }()
}
