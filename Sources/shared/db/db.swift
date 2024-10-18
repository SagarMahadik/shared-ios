import Foundation
import GRDB

public class DatabaseManager {
    public static let shared = DatabaseManager()
    private var dbQueue: DatabaseQueue
    private let schemaVersion: Int = 35 // Increment this when you change the schema
    
    private init() {
        do {
            let fileManager = FileManager.default
            let folderURL = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let dbURL = folderURL.appendingPathComponent("bookmarks.sqlite")
            
                // Configure database options
            var config = Configuration()
            config.foreignKeysEnabled = true // This enables foreign key support
            
            print("DatabaseManager: Database path: \(dbURL.path)")
            
                // Initialize dbQueue before calling needsSchemaUpdate
            dbQueue = try DatabaseQueue(path: dbURL.path,configuration: config)
            
            let needsUpdate = self.needsSchemaUpdate()
            
            if needsUpdate {
                print("DatabaseManager: Schema update needed. Recreating database.")
                try? fileManager.removeItem(at: dbURL)
                    // Reinitialize dbQueue after removing the file
                dbQueue = try DatabaseQueue(path: dbURL.path,configuration: config)
            }
            
            do {
                try dbQueue.read { db in
                    let foreignKeysEnabled = try Int.fetchOne(db, sql: "PRAGMA foreign_keys")
                    print("Foreign keys enabled: \(foreignKeysEnabled == 1)")
                }
            } catch {
                print("Error checking foreign key status: \(error)")
            }
            
            try migrator.migrate(dbQueue)
            
            print("DatabaseManager: Initialization complete")
        } catch {
            fatalError("DatabaseManager: Failed to initialize: \(error)")
        }
    }
    
    private func needsSchemaUpdate() -> Bool {
        do {
            let currentVersion = try dbQueue.read { db in
                try Int.fetchOne(db, sql: "PRAGMA user_version")
            }
            return currentVersion != schemaVersion
        } catch {
            print("Error checking schema version: \(error)")
            return true // Assume update is needed if we can't check
        }
    }
    
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("createSchema_v\(schemaVersion)") { [self] db in
                // Create tags table
            try db.create(table: "tags") { t in
                t.column("_id", .text).notNull().primaryKey()
                t.column("name", .text).notNull()
                t.column("parent", .text).notNull()
                t.column("userId", .text).notNull()
                t.column("isFavorite", .boolean)
            }
            
                // Create collections table
            try db.create(table: "collections") { t in
                t.column("_id", .text).notNull().primaryKey()
                t.column("isFavorite", .boolean).notNull().defaults(to: false)
                t.column("name", .text).notNull()
                t.column("parent", .text).notNull()
                t.column("updatedAt", .date)
                t.column("userId", .text).notNull()
                
                t.foreignKey(["parent"], references: "collections", onDelete: .cascade, onUpdate: .cascade)
            }
            
            try db.create(table: "bookmarks") { t in
                t.column("_id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("url", .text).notNull()
                t.column("parent", .text).notNull().indexed()
                t.column("isFavorite", .boolean).notNull().defaults(to: false)
                t.column("domain", .text).notNull().indexed()
                t.column("updatedAt", .datetime)
                t.column("tags", .text)
                
                t.foreignKey(["parent"], references: "collections", onDelete: .cascade, onUpdate: .cascade)
            }
            
                // Create highlights table with foreign key constraint
            try db.create(table: "highlights") { t in
                t.column("_id", .text).primaryKey()
                t.column("bookmarkId", .text).notNull().references("bookmarks", onDelete: .cascade)
                t.column("isFavorite", .boolean).notNull()
                t.column("color", .text).notNull()
                t.column("isSticky", .boolean).notNull()
                t.column("tags", .text)
            }
            
                // Create highlight_tags table
            try db.create(table: "highlight_tags") { t in
                t.column("highlightId", .text).notNull().references("highlights", onDelete: .cascade)
                t.column("tag", .text).notNull()
                t.primaryKey(["highlightId", "tag"])
            }
            
                // Create bookmark_tags table
            try db.create(table: "bookmark_tags") { t in
                t.column("bookmarkId", .text).notNull().references("bookmarks", onDelete: .cascade)
                t.column("tag", .text).notNull()
                t.primaryKey(["bookmarkId", "tag"])
            }
            
            try db.create(table: "settings") { t in
                t.column("_id", .text).notNull().primaryKey()
                t.column("settings", .text).notNull()
            }
            
            try db.create(table: "sync") { t in
                t.column("_id", .text).notNull().primaryKey()
                t.column("syncId", .integer).notNull()
            }

                // Set the schema version
            try db.execute(sql: "PRAGMA user_version = \(schemaVersion)")
        }
        
        return migrator
    }
    
    public func getDbQueue() -> DatabaseQueue {
        return dbQueue
    }
}
