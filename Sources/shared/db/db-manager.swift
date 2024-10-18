import Foundation
import GRDB
import Combine
import os

public protocol DatabaseRecord: Codable, FetchableRecord, PersistableRecord {}

public class DBManager {
    private let dbQueue: DatabaseQueue
    
    private lazy var collectionRepository: CollectionRepository = {
        CollectionRepository(dbQueue: dbQueue)
    }()
    
    private lazy var tagRepository: TagRepository = {
        TagRepository(dbQueue: dbQueue)
    }()
    
    private lazy var bookmarkRepository: BookmarkRepository = {
        BookmarkRepository(dbQueue: dbQueue)
    }()
    
    private lazy var highlightRepository: HighlightRepository = {
        HighlightRepository(dbQueue: dbQueue)
    }()
    
    private lazy var settingsRepository : SettingsRepository = {
        SettingsRepository(dbQueue: dbQueue)
    }()
    
    private lazy var syncRepository : SyncRepository = {
        SyncRepository(dbQueue: dbQueue)
    }()
    
    public init() {
        self.dbQueue = DatabaseManager.shared.getDbQueue()
    }
    
    public func clearAllData() throws {
        try dbQueue.write { db in
            try Collection.deleteAll(db)
            try Tag.deleteAll(db)
            try Bookmark.deleteAll(db)
            try Highlight.deleteAll(db)
            try Settings.deleteAll(db)
            try Sync.deleteAll(db)
        }
    }

    public func observeCollections() -> AnyPublisher<[Collection], Error> {
        ValueObservation
            .tracking { db in try Collection.fetchAll(db) }
            .publisher(in: dbQueue)
            .eraseToAnyPublisher()
    }
    
    public func observeTags() -> AnyPublisher<[Tag], Error> {
        ValueObservation
            .tracking { db in try Tag.fetchAll(db) }
            .publisher(in: dbQueue)
            .eraseToAnyPublisher()
    }
    
    public func observeSettings() -> AnyPublisher<Settings?, Error> {
        ValueObservation
            .tracking { db -> Settings? in
                try? Settings.fetchOne(db)
            }
            .publisher(in: dbQueue)
            .eraseToAnyPublisher()
    }
    
    public func bulkInsert<T>(_ items: [T]) throws where T: DatabaseRecord {
        switch T.self {
            case is Collection.Type:
                try collectionRepository.bulkInsert(items as! [Collection])
            case is Tag.Type:
                try tagRepository.bulkInsert(items as! [Tag])
            case is Bookmark.Type:
                try bookmarkRepository.bulkInsert(items as! [Bookmark])
            case is Highlight.Type:
                try highlightRepository.bulkInsert(items as! [Highlight])
            default:
                throw NSError(domain: "DBManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported type"])
        }
    }
    
    public struct DBMutationPayload {
        let operation: String
        let arrayOperation: String?
        let collection: String
        let data: [String: Any]
    }
    
    public func mutate(payload: DBMutationPayload) throws {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "DBManager")
                
        let collectionType = CollectionType(rawValue: payload.collection)!
        
        do {
            switch payload.operation {
                case "update":
                    try update(collection: collectionType, with: payload.data)
                case "create":
                        // Implement create logic
                    logger.info("Create operation not yet implemented")
                    break
                case "delete":
                        // Implement delete logic
                    logger.info("Delete operation not yet implemented")
                    break
                default:
                    throw NSError(domain: "DBManagerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown operation"])
            }
        } catch {
            logger.error("Error in mutate function: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func applyDeltaChanges(changes: [DBMutationPayload]) throws {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "DBManager")
        
        do {
            for change in changes {
                try mutate(payload: change)
            }
        } catch {
            logger.error("Error in applyDeltaChanges function: \(error.localizedDescription)")
            throw error
        }
    }

    private func update(collection: CollectionType, with data: [String: Any]) throws {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "DBManager")
        
        var updateId: String
        
        switch collection {
            case .settings:
                updateId = "1"  // Always use "1" as the _id for settings and sync
            default:
                guard let id = data["_id"] as? String else {
                    let error = NSError(domain: "DBManagerError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing _id in update data"])
                    logger.error("Error in create function: \(error.localizedDescription)")
                    throw error
                }
                updateId = id
        }
        
        logger.info("Updating collection: \(collection.rawValue), with data: \(data)")
        
        do {
            switch collection {
                case .collections:
                    try collectionRepository.update(id: updateId, with: data)
                case .tags:
                    try tagRepository.update(id: updateId, with: data)
                case .settings:
                    try settingsRepository.update(id: updateId, with: data)
            }
        } catch {
            logger.error("Error updating \(collection.rawValue): \(error.localizedDescription)")
            throw error
        }
    }
    
    func create(collection: CollectionType, with data: [String: Any]) throws {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "DBManager")
        let updateId: String
        
        if collection == .settings {
            updateId = "1"  // Always use "1" as the _id for settings
        } else {
            guard let id = data["_id"] as? String else {
                let error = NSError(domain: "DBManagerError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing _id in update data"])
                logger.error("Error in create function: \(error.localizedDescription)")
                throw error
            }
            updateId = id
        }
        
        logger.info("Creating in collection: \(collection.rawValue), with data: \(data)")
        
        do {
            switch collection {
                case .settings:
                        // Extract the settings dictionary
                    guard let settingsDict = data["settings"] as? [String: Any] else {
                        let error = NSError(domain: "DBManagerError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing 'settings' in data"])
                        logger.error("Error in create function: \(error.localizedDescription)")
                        throw error
                    }
                        // Decode UserSettings from the settings dictionary
                    let userSettings = try JSONDecoder().decode(UserSettings.self, from: JSONSerialization.data(withJSONObject: settingsDict))
                    let settings = try Settings(_id: updateId, settings: userSettings)
                    try settingsRepository.create(settings)
                case .collections:
                        // Implement collection creation
                    break
                case .tags:
                        // Implement tag creation
                    break
            }
        } catch {
            logger.error("Error creating \(collection.rawValue): \(error.localizedDescription)")
            throw error
        }
    }
    
    public func getTableCount(tableName: String) throws -> Int {
        return try dbQueue.read { db in
            if try db.tableExists(tableName) {
                return try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(tableName)") ?? 0
            } else {
                return 0
            }
        }
    }
    
    public func deleteCollection(id: String) throws {
        try dbQueue.write { db in
            _ = try Collection.deleteOne(db, key: id)
        }
    }
    
    public func getSyncId() throws -> Int? {
        return try syncRepository.getSyncId()
    }
    
    public func setSyncId(_ syncId: Int) throws {
        try syncRepository.setSyncId(syncId)
    }
    
    public enum CollectionType: String {
        case collections
        case tags
        case settings
    }
    
    public enum UpdateError: Error {
        case unsupportedType
        case invalidData
    }
}

