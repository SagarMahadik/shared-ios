import Foundation
import GRDB

public struct Tag: Codable, FetchableRecord, PersistableRecord {
    var _id: String
    var name: String
    var parent: String
    var userId: String
    var isFavorite:Bool?
    
    public static let databaseTableName = "tags"
    
    public enum Columns {
        static let _id = Column(CodingKeys._id)
        static let name = Column(CodingKeys.name)
        static let parent = Column(CodingKeys.parent)
        static let userId = Column(CodingKeys.userId)
        static let isFavorite = Column(CodingKeys.isFavorite)
    }
    
    public init(_id: String = UUID().uuidString,
                name: String,
                parent: String,
                userId: String,
                isFavorite:Bool?
    ) {
        self._id = _id
        self.name = name
        self.parent = parent
        self.userId = userId
        self.isFavorite = isFavorite ?? false
    }
}

public struct PartialTag: Codable {
    var _id: String?
    var name: String?
    var parent: String?
    var userId: String?
}

extension Tag: DatabaseRecord {}
