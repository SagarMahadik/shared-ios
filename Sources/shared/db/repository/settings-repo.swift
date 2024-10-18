import Foundation
import GRDB
import Combine
import os

class SettingsRepository: Repository {
    
    typealias T = Settings
    
    private let dbQueue: DatabaseQueue
    
    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }
    
    func update(id: String, with partialData: [String: Any]) throws {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SettingsRepository")
        
        logger.info("Attempting to update settings with id: \(id)")
        logger.debug("Partial data for update: \(partialData)")
        
        try dbQueue.write { db in
            logger.info("Entered database write transaction")
            
            if var settings = try Settings.fetchOne(db, key: ["_id": id]) {
                logger.info("Found existing settings for id: \(id)")
                
                if var currentSettings = try? settings.userSettings() {
                        // Convert partialData to JSON data
                    let jsonData = try JSONSerialization.data(withJSONObject: partialData, options: [])
                    
                        // Decode JSON data into PartialUserSettings
                    let decoder = JSONDecoder()
                    let partialSettings = try decoder.decode(PartialUserSettings.self, from: jsonData)
                    
                        // Merge partialSettings into currentSettings
                    currentSettings.merge(with: partialSettings)
                    
                    do {
                        settings = try Settings(_id: settings._id, settings: currentSettings)
                        logger.info("Created new Settings object with updated values")
                    } catch {
                        logger.error("Failed to create new Settings object: \(error.localizedDescription)")
                        throw error
                    }
                } else {
                    logger.warning("Failed to parse current user settings")
                    throw NSError(domain: "SettingsRepositoryError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse current user settings"])
                }
                
                do {
                    try settings.update(db)
                    logger.info("Successfully updated settings in database")
                } catch {
                    logger.error("Failed to update settings in database: \(error.localizedDescription)")
                    throw error
                }
            } else {
                logger.error("No settings found for id: \(id)")
                throw NSError(domain: "SettingsRepositoryError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No settings found for id: \(id)"])
            }
        }
        
        logger.info("Completed update operation for settings with id: \(id)")
    }

    func flatten(_ dict: [String: Any], prefix: String = "") -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in dict {
            let newKey = prefix.isEmpty ? key : "\(prefix).\(key)"
            if let subDict = value as? [String: Any] {
                result.merge(flatten(subDict, prefix: newKey)) { (_, new) in new }
            } else {
                result[newKey] = value
            }
        }
        return result
    }
    
    func getAll() throws -> [Settings] {
        try dbQueue.read { db in
            try Settings.fetchAll(db)
        }
    }

    func deleteAll() throws {
        try dbQueue.write { db in
            try Settings.deleteAll(db)
        }
    }
    
    func create(_ item: Settings) throws -> Settings {
        try dbQueue.write { db in
            try item.insert(db)
            return item
        }
    }
    
    func bulkInsert(_ items: [Settings]) throws {
        try dbQueue.write { db in
            for item in items {
                try item.insert(db)
            }
        }
    }
}
