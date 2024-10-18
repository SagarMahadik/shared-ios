import Foundation
import GRDB
import Combine

class SyncRepository: Repository {
    typealias T = Sync
    
    private let dbQueue: DatabaseQueue
    private let defaultId = "1"
    
    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }
    
    func getAll() throws -> [Sync] {
        try dbQueue.read { db in
            try Sync.fetchAll(db)
        }
    }

    func deleteAll() throws {
        try dbQueue.write { db in
            try Sync.deleteAll(db)
        }
    }
    
    func create(_ item: Sync) throws -> Sync {
        try dbQueue.write { db in
            try item.insert(db)
        }
        return item
    }
    
    func bulkInsert(_ items: [Sync]) throws {
        try dbQueue.inTransaction { db in
            for sync in items {
                try sync.insert(db)
            }
            return .commit
        }
    }
    
    func observe() -> AnyPublisher<[Sync], Error> {
        ValueObservation
            .tracking { db in try Sync.fetchAll(db) }
            .publisher(in: dbQueue)
            .eraseToAnyPublisher()
    }
    
    func update(id: String, with partialData: [String: Any]) throws {
        try dbQueue.write { db in
            if var sync = try Sync.fetchOne(db, key: id) {
                for (key, value) in partialData {
                    if key == "syncId", let syncId = value as? Int {
                        sync.syncId = syncId
                    }
                }
                try sync.update(db)
            }
        }
    }
    
    func delete(id: String) throws {
        try dbQueue.write { db in
            _ = try Sync.deleteOne(db, key: id)
        }
    }
    
    func getSyncId() throws -> Int? {
        try dbQueue.read { db in
            let sync = try Sync.fetchOne(db, key: defaultId)
            return sync?.syncId
        }
    }
    
    func setSyncId(_ syncId: Int) throws {
        try dbQueue.write { db in
            if var sync = try Sync.fetchOne(db, key: defaultId) {
                sync.syncId = syncId
                try sync.update(db)
            } else {
                let newSync = Sync(_id: defaultId, syncId: syncId)
                try newSync.insert(db)
            }
        }
    }
}
