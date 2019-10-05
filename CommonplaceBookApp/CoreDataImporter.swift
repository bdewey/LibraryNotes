// Copyright © 2017-present Brian's Brain. All rights reserved.

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
    persistentContainer.loadPersistentStores { description, error in
      if let error = error {
        logger.error("Error opening persistent store: \(error)")
        return
      } else {
        logger.info("Opened persistent store at \(description.url?.absoluteString ?? "")")
      }
      let backgroundContext = persistentContainer.newBackgroundContext()
      backgroundContext.perform {
        let notebookTemplates = importAllPages(
          from: notebook,
          into: backgroundContext
        )
        importLog(
          from: notebook,
          into: backgroundContext,
          templates: notebookTemplates
        )
        importAssets(from: notebook, into: backgroundContext)
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
  ) -> [String: CDChallengeTemplate] {
    var notebookTemplates = [String: CDChallengeTemplate]()
    for (key, properties) in notebook.pageProperties {
      let pageTemplates = importPage(
        from: notebook, key: key,
        properties: properties,
        into: backgroundContext
      )
      notebookTemplates.merge(pageTemplates) { (_, template) -> CDChallengeTemplate in
        assertionFailure()
        return template
      }
    }
    return notebookTemplates
  }

  static func importLog(
    from notebook: NoteArchiveDocument,
    into backgroundContext: NSManagedObjectContext,
    templates: [String: CDChallengeTemplate]
  ) {
    var totalImported = 0
    for entry in notebook.studyLog {
      guard
        let digest = entry.identifier.templateDigest,
        let challengeTemplate = templates[digest],
        let challenge = challengeTemplate.challenge(for: entry.identifier.index)
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

  static func importAssets(
    from notebook: NoteArchiveDocument,
    into backgroundContext: NSManagedObjectContext
  ) {
    var assetCount = 0
    for key in notebook.assetKeys {
      guard let data = notebook.data(for: key) else {
        logger.info("No data for asset \(key)")
        continue
      }
      _ = CDAsset.asset(data: data, context: backgroundContext)
      assetCount += 1
    }
    logger.info("Imported \(assetCount) asset(s)")
  }

  static func importPage(
    from notebook: NoteArchiveDocument,
    key: String,
    properties: PageProperties,
    into backgroundContext: NSManagedObjectContext
  ) -> [String: CDChallengeTemplate] {
    let uuid = UUID(uuidString: key)!
    let page = CDPage.getOrCreate(uuid: uuid, context: backgroundContext)
    page.timestamp = properties.timestamp
    page.title = properties.title
    page.hashtags = NSSet(
      array: properties.hashtags
        .map { CDHashtag.getOrCreate(name: $0, context: backgroundContext) }
    )
    importPageContents(from: notebook, key: key, into: page)
    // Delete all existing templates
    backgroundContext.deleteAllObjects(in: page.challengeTemplates)
    // Import templates
    let keysAndTemplates = Dictionary(
      uniqueKeysWithValues: properties.cardTemplates.compactMap {
        try? convertTemplate(identifierString: $0, notebook: notebook, context: backgroundContext)
      }
    )
    keysAndTemplates.values.forEach {
      page.addToChallengeTemplates($0)
    }
    return keysAndTemplates
  }

  static func convertTemplate(
    identifierString: String,
    notebook: NoteArchiveDocument,
    context: NSManagedObjectContext
  ) throws -> (key: String, template: CDChallengeTemplate)? {
    guard
      let templateKey = ChallengeTemplateArchiveKey(identifierString),
      let template = notebook.challengeTemplate(for: identifierString)
    else {
      return nil
    }
    let templateObject = CDChallengeTemplate(context: context)
    templateObject.serialized = try YAMLEncoder().encode(template)
    templateObject.type = templateKey.type
    // Import challenges
    let challenges = template.challenges.map { challenge -> CDChallenge in
      let challengeObject = CDChallenge(context: context)
      challengeObject.key = String(describing: challenge.challengeIdentifier.index)
      return challengeObject
    }
    templateObject.addToChallenges(NSSet(array: challenges))
    return (key: templateKey.digest, template: templateObject)
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

private extension CDChallengeTemplate {
  func challenge(for index: Int) -> CDChallenge? {
    challenges?
      .compactMap { challenge -> CDChallenge? in
        guard
          let challenge = challenge as? CDChallenge,
          challenge.key == String(describing: index)
        else {
          return nil
        }
        return challenge
      }.first
  }
}
