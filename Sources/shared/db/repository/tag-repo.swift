import Foundation
import GRDB
import Combine

class
TagRepository: Repository {
    func update(id: String, with partialData: [String : Any]) throws {
        print("tag update")
    }
    
    typealias T = Tag
    
    private let dbQueue: DatabaseQueue
    
    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }
    
    func getAll() throws -> [Tag] {
        try dbQueue.read { db in
            try Tag.fetchAll(db)
        }
    }

    func deleteAll() throws {
        try dbQueue.write { db in
            try Tag.deleteAll(db)
        }
    }
        
    public func create(_ item :Tag) throws -> Tag {
        try dbQueue.write { db in
            try item.insert(db)
        }
        
        return item
    }
    
    func bulkInsert(_ items: [Tag]) throws {
        try dbQueue.inTransaction { db in
            for tag in items {
                try tag.insert(db)
            }
            return .commit
        }
    }
    
    func observe() -> AnyPublisher<[Tag], Error> {
        ValueObservation
            .tracking { db in try Tag.fetchAll(db) }
            .publisher(in: dbQueue)
            .eraseToAnyPublisher()
    }
    
    

    
    func delete(id: String) throws {
        try dbQueue.write { db in
            _ = try Tag.deleteOne(db, key: id)
        }
    }
}
