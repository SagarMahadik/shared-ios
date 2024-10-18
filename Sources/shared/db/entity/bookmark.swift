import Foundation
import GRDB

public struct Bookmark: Codable, FetchableRecord, PersistableRecord {
    var _id: String
    var title: String
    var url: String
    var isFavorite: Bool
    var domain: String
    var updatedAt: Date?
    var parent:String
    var tags: [String]
    
    public static let databaseTableName = "bookmarks"
    
    enum CodingKeys: String, CodingKey {
        case _id
        case title
        case url
        case isFavorite
        case domain
        case updatedAt
        case tags
        case parent
    }
    
    public enum Columns {
        static let id = Column(CodingKeys._id)
        static let title = Column(CodingKeys.title)
        static let url = Column(CodingKeys.url)
        static let isFavorite = Column(CodingKeys.isFavorite)
        static let domain = Column(CodingKeys.domain)
        static let parent = Column(CodingKeys.parent)
        static let updatedAt = Column(CodingKeys.updatedAt)
        static let tags = Column(CodingKeys.tags)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        _id = try container.decode(String.self, forKey: ._id)
        title = try container.decode(String.self, forKey: .title)
        url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        domain = try container.decodeIfPresent(String.self, forKey: .domain) ?? ""
        parent = try container.decodeIfPresent(String.self, forKey: .parent) ?? "0"
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        
        if let updatedAtString = try container.decodeIfPresent(String.self, forKey: .updatedAt) {
            let formatter = ISO8601DateFormatter()
            updatedAt = formatter.date(from: updatedAtString)
        } else {
            updatedAt = nil
        }
    }
    
    public init(_id: String = UUID().uuidString,
                title: String,
                url: String,
                isFavorite: Bool = false,
                domain: String,
                updatedAt: Date? = nil,
                parent:String,
                tags: [String] = []) {
        self._id = _id
        self.title = title
        self.url = url
        self.isFavorite = isFavorite
        self.domain = domain
        self.parent = parent
        self.updatedAt = updatedAt
        self.tags = tags
    }
    
    public func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = _id
        container[Columns.title] = title
        container[Columns.url] = url
        container[Columns.isFavorite] = isFavorite
        container[Columns.domain] = domain
        container[Columns.parent] = parent
        container[Columns.updatedAt] = updatedAt
        container[Columns.tags] = tags.joined(separator: ",")
    }
}


public struct BookmarkTag: Codable, FetchableRecord, PersistableRecord {
    var bookmarkId: String
    var tag: String
    
    public static let databaseTableName = "bookmark_tags"
    
    enum CodingKeys: String, CodingKey {
        case bookmarkId
        case tag
    }
    
    public enum Columns {
        static let bookmarkId = Column(CodingKeys.bookmarkId)
        static let tag = Column(CodingKeys.tag)
    }
}

extension Bookmark: DatabaseRecord {}
