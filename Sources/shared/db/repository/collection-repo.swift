import Foundation
import GRDB
import Combine

protocol Repository {
    associatedtype T
    func getAll() throws -> [T]
    func create(_ item: T) throws -> T
    func bulkInsert(_ items: [T]) throws
    func update(id: String, with partialData: [String: Any]) throws
}


class CollectionRepository: Repository {
    typealias T = Collection
    
    private let dbQueue: DatabaseQueue
    
    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }
    
    func getAll() throws -> [Collection] {
        try dbQueue.read { db in
            try Collection.fetchAll(db)
        }
    }

    func removeAll() throws {
        try dbQueue.write { db in
            try Collection.deleteAll(db)
        }
    }
    
    func create(_ item: Collection) throws -> Collection {
        try dbQueue.write { db in
            try item.insert(db)
        }
        return item
    }
    
    public func bulkInsert(_ collections: [Collection]) throws {
        try dbQueue.inTransaction { db in
                // First, check if the root collection exists, if not, create it
            let rootExists = try Collection.filter(Column("_id") == "0").fetchCount(db) > 0
            if !rootExists {
                let rootCollection = Collection(
                    _id: "0",
                    isFavorite: false,
                    name: "Root Collection",
                    parent: "0",  // Root is its own parent
                    updatedAt: Date(),
                    userId: "system"  // Or any appropriate userId for the root
                )
                try rootCollection.save(db)
                print("Root collection created")
            }
            
                // Sort collections so that parents are inserted before children
            let sortedCollections = try topologicalSort(collections)
            print("Sorted collections: \(sortedCollections)")
            
            for collection in sortedCollections {
                do {
                        // Insert or update the collection
                    try collection.save(db)
                    print("Successfully inserted/updated collection: \(collection._id)")
                } catch {
                        // Throw a custom error with more details
                    throw NSError(domain: "Collections", code: 3, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to insert collection",
                        "collectionId": collection._id,
                        "parentId": collection.parent,
                        "underlyingError": error.localizedDescription
                    ])
                }
            }
            return .commit
        }
    }
    
    private func topologicalSort(_ collections: [Collection]) throws -> [Collection] {
        var sorted: [Collection] = []
        var visited: Set<String> = []
        var tempMark: Set<String> = []
        
        func visit(_ collection: Collection) throws {
            if tempMark.contains(collection._id) {
                throw NSError(domain: "Collections", code: 1, userInfo: [NSLocalizedDescriptionKey: "Circular dependency detected"])
            }
            if !visited.contains(collection._id) {
                tempMark.insert(collection._id)
                let parent = collections.first(where: { $0._id == collection.parent })
                if let parent = parent {
                    try visit(parent)
                }
                visited.insert(collection._id)
                tempMark.remove(collection._id)
                sorted.append(collection)
            }
        }
        
        for collection in collections {
            if !visited.contains(collection._id) {
                try visit(collection)
            }
        }
        
        return sorted
    }
    
    func observe() -> AnyPublisher<[Collection], Error> {
        ValueObservation
            .tracking { db in try Collection.fetchAll(db) }
            .publisher(in: dbQueue)
            .eraseToAnyPublisher()
    }
    
    func update(id: String, with partialData: [String: Any]) throws {
        print("partial data\(partialData)")
        
        try dbQueue.write { db in
            if var collection = try Collection.fetchOne(db, key: id) {
                for (key, value) in partialData {
                    switch key {
                        case "isFavorite":
                            if let isFavorite = value as? Bool {
                                collection.isFavorite = isFavorite
                            } else if let isFavoriteInt = value as? Int {
                                collection.isFavorite = isFavoriteInt != 0
                            }
                        case "name":
                            if let name = value as? String {
                                collection.name = name
                            }
                        case "parent":
                            if let parent = value as? String {
                                collection.parent = parent
                            }
                        case "updatedAt":
                            print("updatedAt type: \(type(of: value))")
                            print("updatedAt value: \(value)")
                            if let updatedAtValue = value as? String {
                                let formatter = ISO8601DateFormatter()
                                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                                if let date = formatter.date(from: updatedAtValue) {
                                    collection.updatedAt = date
                                } else {
                                    print("Failed to parse date from string: \(updatedAtValue)")
                                }
                            } else {
                                print("Unexpected type for updatedAt: \(type(of: value))")
                            }
                        case "userId":
                            if let userId = value as? String {
                                collection.userId = userId
                            }
                        default:
                            break
                    }
                }
                try collection.update(db)
            } else {
                throw NSError(domain: "CollectionRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Collection not found"])
            }
        }
    }

}

