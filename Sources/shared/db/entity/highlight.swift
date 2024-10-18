import Foundation
import GRDB

public struct Highlight: Codable, FetchableRecord, PersistableRecord {
    var _id: String
    var bookmarkId: String
    var isFavorite: Bool
    var color: String
    var isSticky: Bool
    var tags: [String]
    
    public static let databaseTableName = "highlights"
    
    enum CodingKeys: String, CodingKey {
        case _id
        case bookmarkId
        case isFavorite
        case color
        case isSticky
        case tags
    }
    
    public enum Columns {
        static let id = Column(CodingKeys._id)
        static let bookmarkId = Column(CodingKeys.bookmarkId)
        static let isFavorite = Column(CodingKeys.isFavorite)
        static let color = Column(CodingKeys.color)
        static let isSticky = Column(CodingKeys.isSticky)
        static let tags = Column(CodingKeys.tags)
    }
    
    public init(_id: String = UUID().uuidString,
                bookmarkId: String,
                isFavorite: Bool = false,
                color: String,
                isSticky: Bool = false,
                tags: [String] = []) {
        self._id = _id
        self.bookmarkId = bookmarkId
        self.isFavorite = isFavorite
        self.color = color
        self.isSticky = isSticky
        self.tags = tags
    }
    
    public func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = _id
        container[Columns.bookmarkId] = bookmarkId
        container[Columns.isFavorite] = isFavorite
        container[Columns.color] = color
        container[Columns.isSticky] = isSticky
        container[Columns.tags] = tags.joined(separator: ",")
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _id = try container.decode(String.self, forKey: ._id)
        bookmarkId = try container.decode(String.self, forKey: .bookmarkId)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        color = try container.decode(String.self, forKey: .color)
        isSticky = try container.decodeIfPresent(Bool.self, forKey: .isSticky) ?? false
        if let tagsString = try container.decodeIfPresent(String.self, forKey: .tags) {
            tags = tagsString.split(separator: ",").map(String.init)
        } else {
            tags = []
        }
    }
}

public struct HighlightTag: Codable, FetchableRecord, PersistableRecord {
    var highlightId: String
    var tag: String
    
    public static let databaseTableName = "highlight_tags"
    
    enum CodingKeys: String, CodingKey {
        case highlightId
        case tag
    }
    
    public enum Columns {
        static let highlightId = Column(CodingKeys.highlightId)
        static let tag = Column(CodingKeys.tag)
    }
    
    public init(highlightId: String, tag: String) {
        self.highlightId = highlightId
        self.tag = tag
    }
}

extension Highlight: DatabaseRecord {}
