import Foundation


public struct AccessibilityFeature: Identifiable, Codable {
    public let id: UUID
    public let key: String
    public let type: String
    public let options: [String]?
    public let range: [Double]?
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.key = try container.decode(String.self, forKey: .key)
        self.type = try container.decode(String.self, forKey: .type)
        self.options = try container.decodeIfPresent([String].self, forKey: .options)
        self.range = try container.decodeIfPresent([Double].self, forKey: .range)
    }
    
    enum CodingKeys: String, CodingKey {
        case key, type, options, range
    }
}

public struct SettingsPage: Codable {
    public let accessibilityFeatures: [AccessibilityFeature]
}

public struct Translation: Codable {
    public var name: String
    public var description: String?
}
