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

extension UIMenu.Identifier {
  static let openMenu = UIMenu.Identifier("org.brians-brain.LibraryNotes.Open")
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

  internal static var isUITesting: Bool = CommandLine.arguments.contains("--uitesting")

  override func buildMenu(with builder: UIMenuBuilder) {
    let newNoteCommand = UIKeyCommand(
      title: "New Note",
      action: #selector(NotebookViewController.makeNewNote),
      input: "n",
      modifierFlags: [.command]
    )
    let openMenu = UIMenu(
      title: "",
      image: nil,
      identifier: .openMenu,
      options: .displayInline,
      children: [
        newNoteCommand,
        UIKeyCommand(title: "Open...", action: #selector(openCommand), input: "o", modifierFlags: .command),
      ]
    )
    builder.replace(menu: .newScene, with: openMenu)
    builder.insertSibling(UIMenu(options: .displayInline, children: [
      UIKeyCommand(title: "Review", action: #selector(DocumentListViewController.performReview), input: "r", modifierFlags: [.command, .shift]),
    ]), afterMenu: .openMenu)
    builder.insertSibling(UIMenu(options: .displayInline, children: [
      UIKeyCommand(title: "Random Quotes", action: #selector(DocumentListViewController.showRandomQuotes), input: "1", modifierFlags: [.command]),
    ]), beforeMenu: .bringAllToFront)
    builder.insertChild(
      UIMenu(options: .displayInline, children: [DocumentListViewController.groupByYearReadCommand]),
      atStartOfMenu: .view
    )
    builder.insertChild(DocumentListViewController.sortMenu, atStartOfMenu: .view)
    if #available(macCatalyst 16.0, iOS 16.0, *) {
      builder.remove(menu: .document)
    }
    let exportMenu = UIMenu(title: "Export", image: nil, identifier: .init("org.brians-brain.LibraryNotes.Export"), options: [], children: [
      UICommand(title: "Export to CSV...", action: #selector(DocumentListViewController.exportToCSV)),
      UICommand(title: "Export to Zip...", action: #selector(DocumentListViewController.exportToZip)),
    ])
    builder.insertChild(
      UIMenu(
        title: "",
        image: nil,
        identifier: .init("org.brians-brain.LibraryNotes.Import"),
        options: .displayInline,
        children: [
          UIKeyCommand(title: "Import...", action: #selector(DocumentListViewController.importBooks), input: "i", modifierFlags: [.shift, .command]),
          exportMenu,
        ]
      ),
      atEndOfMenu: .file
    )
    builder.insertChild(UIMenu(title: "", options: .displayInline, children: [UICommand(title: "Send feedback to the developer...", action: #selector(DocumentListViewController.sendFeedback))]), atStartOfMenu: .help)
    builder.replace(menu: .format, with: UIMenu(title: "Format", children: [
      UIMenu(title: "Block formatting", identifier: .init("org.brians-brain.block-format"), options: .displayInline, children: [
        UIKeyCommand(title: "Heading", action: #selector(TextEditingFormattingActions.toggleHeading), input: "h", modifierFlags: [.shift, .command]),
        UIKeyCommand(title: "Summary", action: #selector(TextEditingFormattingActions.toggleSummaryParagraph), input: "s", modifierFlags: [.shift, .command])
      ]),
      UIKeyCommand(title: "Bold", action: #selector(toggleBoldface), input: "b", modifierFlags: .command),
      UIKeyCommand(title: "Italic", action: #selector(toggleItalics), input: "i", modifierFlags: .command),
    ]))
  }

  @objc func openCommand() {
    let options = UIWindowScene.ActivationRequestOptions()
    options.preferredPresentationStyle = .prominent
    UIApplication.shared.requestSceneSessionActivation(nil, userActivity: nil, options: options)
  }
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
