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
      } else {
        logger.info("Opened persistent store at \(description.url?.absoluteString ?? "")")
      }
      let backgroundContext = persistentContainer.newBackgroundContext()
      backgroundContext.perform {
        for (key, properties) in notebook.pageProperties {
          let uuid = UUID(uuidString: key)!
          let page = CDPage.getOrCreate(uuid: uuid, context: backgroundContext)
          page.timestamp = properties.timestamp
          page.title = properties.title
          for hashtag in properties.hashtags {
            let hashtagRecord = CDHashtag.getOrCreate(name: hashtag, context: backgroundContext)
            page.hashtags = page.hashtags?.adding(hashtagRecord) as NSSet?
          }
          if let contents = try? notebook.currentTextContents(for: key) {
            page.contents.flatMap { backgroundContext.delete($0) }
            let contentsObject = CDPageContents(context: backgroundContext)
            contentsObject.contents = contents
            page.contents = contentsObject
          }
          // Delete all existing templates
          backgroundContext.deleteAllObjects(in: page.challengeTemplates)
          // Import templates
          for templateKeyString in properties.cardTemplates {
            guard
              let templateKey = ChallengeTemplateArchiveKey(templateKeyString),
              let template = notebook.challengeTemplate(for: templateKeyString)
            else {
              continue
            }
            do {
              let templateObject = CDChallengeTemplate(context: backgroundContext)
              templateObject.serialized = try YAMLEncoder().encode(template)
              templateObject.type = templateKey.type
              // Import challenges
              let challenges = template.challenges.map { challenge -> CDChallenge in
                let challengeObject = CDChallenge(context: backgroundContext)
                challengeObject.key = String(describing: challenge.challengeIdentifier.index)
                return challengeObject
              }
              templateObject.challenges = Set(challenges) as NSSet
              page.challengeTemplates = page.challengeTemplates?.adding(templateObject) as NSSet?
              logger.info("Imported template \(templateKeyString)")
            } catch {
              logger.error("Error converting template \(templateKeyString): \(error)")
            }
          }
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

private extension NSManagedObjectContext {
  func deleteAllObjects(in set: NSSet?) {
    guard let set = set else { return }
    for object in set {
      guard let managedObject = object as? NSManagedObject else { continue }
      delete(managedObject)
    }
  }
}
