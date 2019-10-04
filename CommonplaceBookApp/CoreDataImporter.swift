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
        for (key, properties) in notebook.pageProperties {
          importPage(from: notebook, key: key, properties: properties, into: backgroundContext)
        }
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
    templateObject.serialized = try YAMLEncoder().encode(template)
    templateObject.type = templateKey.type
    // Import challenges
    let challenges = template.challenges.map { challenge -> CDChallenge in
      let challengeObject = CDChallenge(context: context)
      challengeObject.key = String(describing: challenge.challengeIdentifier.index)
      return challengeObject
    }
    templateObject.challenges = Set(challenges) as NSSet
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
