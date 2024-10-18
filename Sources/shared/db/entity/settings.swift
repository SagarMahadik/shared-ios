//
//  File.swift
//  
//
//  Created by sgrmhdk on 07/10/24.
//

import Foundation
import GRDB

public struct UserSettings: Codable {
    public var dock: DockSettings
    public var sidebar: SidebarSettings
}

public struct DockSettings: Codable {
    public var size: Int
}

public struct SidebarSettings: Codable {
    public var position: String
    public var size: Double
}

public struct Settings: Codable, FetchableRecord, PersistableRecord {
    public var _id: String
    public var settings: String
    
    public static let databaseTableName = "settings"
    
    public enum Columns {
        static let id = Column(CodingKeys._id)
        static let settings = Column(CodingKeys.settings)
    }
    
    public init(_id: String = UUID().uuidString,
                settings: UserSettings) throws {
        self._id = _id
        let encoder = JSONEncoder()
        self.settings = try String(data: encoder.encode(settings), encoding: .utf8) ?? ""
    }
    
    public init(row: Row) throws {
        _id = row[Columns.id]
        settings = row[Columns.settings]
    }
    
    public func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = _id
        container[Columns.settings] = settings
    }
    
    public func userSettings() throws -> UserSettings {
        let decoder = JSONDecoder()
        guard let data = settings.data(using: .utf8) else {
            throw NSError(domain: "Settings", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert settings string to data"])
        }
        return try decoder.decode(UserSettings.self, from: data)
    }
}

extension Settings: DatabaseRecord {}

public struct PartialSettings: Codable {
    var _id: String?
    var settings: UserSettings?
}

public struct PartialUserSettings: Codable {
    public var dock: PartialDockSettings?
    public var sidebar: PartialSidebarSettings?
}

public struct PartialDockSettings: Codable {
    public var size: Int?
}

public struct PartialSidebarSettings: Codable {
    public var position: String?
    public var size: Double?
}

extension UserSettings {
    mutating func merge(with partial: PartialUserSettings) {
        if let partialDock = partial.dock {
            dock.merge(with: partialDock)
        }
        if let partialSidebar = partial.sidebar {
            sidebar.merge(with: partialSidebar)
        }
    }
}

extension DockSettings {
    mutating func merge(with partial: PartialDockSettings) {
        if let size = partial.size {
            self.size = size
        }
    }
}

extension SidebarSettings {
    mutating func merge(with partial: PartialSidebarSettings) {
        if let position = partial.position {
            self.position = position
        }
        if let size = partial.size {
            self.size = size
        }
    }
}
