import Foundation
import GRDB
import Combine

class
HighlightRepository:Repository {
    func update(id: String, with partialData: [String : Any]) throws {
        print("update highlight")
    }
    
    typealias T = Highlight
    
    private let dbQueue: DatabaseQueue
    
    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }
    
    func getAll() throws -> [Highlight] {
        try dbQueue.read { db in
            try Highlight.fetchAll(db)
        }
    }
    
    func deleteAll() throws {
        try dbQueue.write { db in
            try Highlight.deleteAll(db)
        }
    }

    public func create(_ item :Highlight) throws -> Highlight {
        try dbQueue.write { db in
            try item.insert(db)
        }
        
        return item
    }
    
    func bulkInsert(_ items: [Highlight]) throws {
        try dbQueue.inTransaction { db in
            for highlight in items {
                do {
                    try highlight.insert(db)
                    
                    for tag in highlight.tags {
                        let highlightTag = HighlightTag(highlightId: highlight._id, tag: tag)
                        try highlightTag.insert(db)
                    }
                } catch {
                    throw error
                }
            }
            return .commit
        }
        print("Bulk insert of bookmarks completed")
    }
}
