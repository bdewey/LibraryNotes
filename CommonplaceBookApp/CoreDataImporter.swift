// Copyright © 2019 Brian's Brain. All rights reserved.

import CoreData
import Foundation
import Logging
import Yams

private let logger = Logger(label: "org.brians-brain.CoreData")

/// Imports a NoteArchiveDocument into a Core Data database.
public enum CoreDataImporter {
  public static func importNotebook(
    _ notebook: NoteArchiveDocument
  ) {
    let persistentContainer = NSPersistentContainer(name: "Notes")
    persistentContainer.loadPersistentStores { (description, error) in
      if let error = error {
        logger.error("Error opening persistent store: \(error)")
        return
      } else {
        logger.info("Opened persistent store at \(description.url?.absoluteString ?? "")")
      }
      let backgroundContext = persistentContainer.newBackgroundContext()
      backgroundContext.perform {
        importAllPages(from: notebook, into: backgroundContext)
        importLog(from: notebook, into: backgroundContext)
        do {
          try backgroundContext.save()
          logger.info("Successfully saved Core Data content")
        } catch {
          logger.error("Unable to save core data changes: \(error)")
        }
      }
    }
  }
}

// MARK: - Private

private extension CoreDataImporter {
  static func importAllPages(
    from notebook: NoteArchiveDocument,
    into backgroundContext: NSManagedObjectContext
  ) {
    for (key, properties) in notebook.pageProperties {
      importPage(from: notebook, key: key, properties: properties, into: backgroundContext)
    }
  }

  static func importLog(
    from notebook: NoteArchiveDocument,
    into backgroundContext: NSManagedObjectContext
  ) {
    var totalImported = 0
    for entry in notebook.studyLog {
      guard
        let challenge = try? CDChallenge.fetch(identifier: entry.identifier)
      else {
        logger.error("Could not find a challenge for \(entry.identifier)")
        continue
      }
      guard entry.statistics.correct > 0 else {
        challenge.suppressUntil = nil
        continue
      }
      if let priorStudyDate = challenge.lastStudyDate {
        let delta = Swift.max(entry.timestamp.timeIntervalSince(priorStudyDate), TimeInterval.day)
        let factor = pow(2.0, 1.0 - Double(entry.statistics.incorrect))
        challenge.suppressUntil = entry.timestamp.addingTimeInterval(delta * factor)
      } else {
        // TODO: This copies the current study logic but it seems wrong
        // because it doesn't take correct/incorrect into account.
        challenge.suppressUntil = entry.timestamp.addingTimeInterval(.day)
      }
      challenge.lastStudyDate = entry.timestamp
      challenge.totalCorrect += Int32(entry.statistics.correct)
      challenge.totalIncorrect += Int32(entry.statistics.incorrect)

      let entryObject = CDStudyLogEntry(context: backgroundContext)
      entryObject.correct = Int16(entry.statistics.correct)
      entryObject.incorrect = Int16(entry.statistics.incorrect)
      entryObject.timestamp = entry.timestamp
      challenge.addToStudyLogEntries(entryObject)
      totalImported += 1
    }
    logger.info("Imported \(totalImported) log entries")
  }

  static func importPage(
    from notebook: NoteArchiveDocument,
    key: String,
    properties: PageProperties,
    into backgroundContext: NSManagedObjectContext
  ) {
    let uuid = UUID(uuidString: key)!
    let page = CDPage.getOrCreate(uuid: uuid, context: backgroundContext)
    page.timestamp = properties.timestamp
    page.title = properties.title
    page.hashtags = NSSet(array: properties.hashtags
      .map { CDHashtag.getOrCreate(name: $0, context: backgroundContext) }
    )
    importPageContents(from: notebook, key: key, into: page)
    // Delete all existing templates
    backgroundContext.deleteAllObjects(in: page.challengeTemplates)
    // Import templates
    page.challengeTemplates = NSSet(array: properties.cardTemplates
      .compactMap {
        try? convertTemplate(identifierString: $0, notebook: notebook, context: backgroundContext)
      }
    )
    logger.info("page: \(page)")
  }

  static func convertTemplate(
    identifierString: String,
    notebook: NoteArchiveDocument,
    context: NSManagedObjectContext
  ) throws -> CDChallengeTemplate? {
    guard
      let templateKey = ChallengeTemplateArchiveKey(identifierString),
      let template = notebook.challengeTemplate(for: identifierString)
    else {
      return nil
    }
    let templateObject = CDChallengeTemplate(context: context)
    templateObject.legacyIdentifier = templateKey.digest
    templateObject.serialized = try YAMLEncoder().encode(template)
    templateObject.type = templateKey.type
    // Import challenges
    let challenges = template.challenges.map { challenge -> CDChallenge in
      let challengeObject = CDChallenge(context: context)
      challengeObject.key = String(describing: challenge.challengeIdentifier.index)
      return challengeObject
    }
    templateObject.addToChallenges(NSSet(array: challenges))
    return templateObject
  }

  static func importPageContents(
    from notebook: NoteArchiveDocument,
    key: String,
    into page: CDPage
  ) {
    guard let context = page.managedObjectContext else { return }
    if let contents = try? notebook.currentTextContents(for: key) {
      page.contents.flatMap { context.delete($0) }
      let contentsObject = CDPageContents(context: context)
      contentsObject.contents = contents
      page.contents = contentsObject
    }
  }
}

private extension NSManagedObjectContext {
  func deleteAllObjects(in set: NSSet?) {
    guard let set = set else { return }
    for object in set {
      guard let managedObject = object as? NSManagedObject else { continue }
      delete(managedObject)
    }
  }
}
