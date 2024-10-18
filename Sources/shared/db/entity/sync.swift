import Foundation
import GRDB

struct Sync: Codable, FetchableRecord, PersistableRecord {
    var _id: String
    var syncId: Int
    
    enum CodingKeys: String, CodingKey {
        case _id = "_id"
        case syncId
    }
}
