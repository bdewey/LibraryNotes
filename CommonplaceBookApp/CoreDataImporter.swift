// Copyright © 2019 Brian's Brain. All rights reserved.

import CoreData
import Foundation
import Logging

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
          let request: NSFetchRequest<CDPage> = CDPage.fetchRequest()
          request.resultType = .managedObjectIDResultType
          request.predicate = NSPredicate(format: "uuid == %@", uuid as CVarArg)
          do {
            let existingRecords = try request.execute()
            if existingRecords.isEmpty {
              let page = CDPage(context: backgroundContext)
              page.uuid = uuid
              page.timestamp = properties.timestamp
              logger.info("Made a record for key \(key)")
            } else {
              logger.info("Did not make a record for \(key) because it already existed")
            }
          } catch {
            logger.error("Unexpected error on uuid \(key): \(error)")
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
