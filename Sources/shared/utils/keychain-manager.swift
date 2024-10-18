import Security
import SwiftUI
import os

public class KeychainManager {
    public static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "KeychainManager", category: "Keychain")
    
    static func save(key: String, data: Data) -> OSStatus {
        let query = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ] as [String : Any]
        
            // Ensure old value is removed before adding new one
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        logger.debug("Saving to Keychain - Key: \(key), Status: \(status)")
        return status
    }
    
    static func load(key: String) -> Data? {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String : Any]
        
        var dataTypeRef: AnyObject?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        switch status {
            case errSecSuccess:
                logger.debug("Loading from Keychain - Key: \(key), Status: Success")
                return dataTypeRef as? Data
            case errSecItemNotFound:
                logger.error("Loading from Keychain - Key: \(key), Error: Item not found")
            default:
                logger.error("Loading from Keychain - Key: \(key), Status: \(status)")
        }
        return nil
    }
    
    static func delete(key: String) -> Bool {
        logger.debug("Attempting to delete from Keychain - Key: \(key)")
        let query = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: key
        ] as [String : Any]
        
        let status = SecItemDelete(query as CFDictionary)
        let success = (status == errSecSuccess)
        logger.debug("Deleting from Keychain - Key: \(key), Status: \(status), Success: \(success)")
        return success
    }
}
