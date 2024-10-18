import Foundation
import GRDB
import Combine

class
BookmarkRepository:Repository {
    func update(id: String, with partialData: [String : Any]) throws {
        print("call update bookmark")
    }
    
    typealias T = Bookmark
    
    private let dbQueue: DatabaseQueue
    
    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }
    
    func getAll() throws -> [Bookmark] {
        try dbQueue.read { db in
            try Bookmark.fetchAll(db)
        }
    }

    func removeAll() throws {
        try dbQueue.write { db in
            try Bookmark.deleteAll(db)
        }
    }
    
    public func create(_ item :Bookmark) throws -> Bookmark {
        try dbQueue.write { db in
            try item.insert(db)
        }
        
        return item
    }
    
    func bulkInsert(_ items: [Bookmark]) throws {
        try dbQueue.inTransaction { db in
            for bookmark in items {
                do {
                    try bookmark.insert(db)
                    
                    for tag in bookmark.tags {
                        let bookmarkTag = BookmarkTag(bookmarkId: bookmark._id, tag: tag)
                        try bookmarkTag.insert(db)
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
