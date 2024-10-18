import Foundation
import GRDB

public struct Collection: Codable, FetchableRecord, PersistableRecord {
    public var _id: String
    public var isFavorite: Bool
    public var name: String
    public var parent: String
    public var updatedAt: Date?
    public var userId: String
    
    public static let databaseTableName = "collections"
    
    enum CodingKeys: String, CodingKey {
        case _id
        case isFavorite
        case name
        case parent
        case updatedAt
        case userId
    }
    
    public enum Columns {
        static let _id = Column(CodingKeys._id)
        static let isFavorite = Column(CodingKeys.isFavorite)
        static let name = Column(CodingKeys.name)
        static let parent = Column(CodingKeys.parent)
        static let updatedAt = Column(CodingKeys.updatedAt)
        static let userId = Column(CodingKeys.userId)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _id = try container.decode(String.self, forKey: ._id)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        name = try container.decode(String.self, forKey: .name)
        parent = try container.decode(String.self, forKey: .parent)
        userId = try container.decode(String.self, forKey: .userId)
        
            // Custom decoding for updatedAt
        if let updatedAtString = try container.decodeIfPresent(String.self, forKey: .updatedAt) {
            let formatter = ISO8601DateFormatter()
            updatedAt = formatter.date(from: updatedAtString)
        } else {
            updatedAt = nil
        }
    }
    
        // Update the existing initializer
    public init(_id: String = UUID().uuidString,
                isFavorite: Bool? = false,
                name: String,
                parent: String,
                updatedAt: Date? = nil,
                userId: String) {
        self._id = _id
        self.isFavorite = isFavorite ?? false
        self.name = name
        self.parent = parent
        self.updatedAt = updatedAt
        self.userId = userId
    }
}

struct PartialCollection {
    var isFavorite: Bool?
    var name: String?
    var parent: String?
    var updatedAt: Date?
    var userId: String?
    
    init(from dictionary: [String: Any]) {
        self.isFavorite = dictionary["isFavorite"] as? Bool
        self.name = dictionary["name"] as? String
        self.parent = dictionary["parent"] as? String
        
        print("Type of updatedAt: \(type(of: dictionary["updatedAt"]))")

        
        if let updatedAtString = dictionary["updatedAt"] as? String {
            let formatter = ISO8601DateFormatter()
            self.updatedAt = formatter.date(from: updatedAtString)
        } else if let updatedAtDate = dictionary["updatedAt"] as? Date {
            self.updatedAt = updatedAtDate
        }
        
        self.userId = dictionary["userId"] as? String
    }
}


extension Collection: DatabaseRecord {}
