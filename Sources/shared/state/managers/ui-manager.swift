//
//  File.swift
//  
//
//  Created by sgrmhdk on 07/10/24.
//

import Foundation

enum ItemType: String {
    case collections
}

class UiManager {
    private let dataManager: DataManager

    
    public init() {
  
        self.dataManager = DataManager()
    }
    
    func setFavorite(payload: Any) {
        print("Entering setFavorite with payload: \(payload)")
        
        guard let payloadDict = payload as? [String: Any] else {
            print("Error: Failed to cast payload to [String: Any]")
            return
        }
        
        guard let index = payloadDict["index"] as? Int,
              let itemId = payloadDict["_id"] as? String,
              let entity = payloadDict["entity"] as? String,
              let value = payloadDict["value"] as? Bool else {
            print("Error: Missing or invalid payload values")
            print("index: \(payloadDict["index"] ?? "nil")")
            print("_id: \(payloadDict["_id"] ?? "nil")")
            print("entity: \(payloadDict["entity"] ?? "nil")")
            print("value: \(payloadDict["value"] ?? "nil")")
            return
        }
        
        print("Parsed payload values:")
        print("index: \(index), itemId: \(itemId), entity: \(entity), value: \(value)")
        
        let dataToUpdate: [String: Any] = [
            "_id": itemId,
            "isFavorite": value
        ]
        
        let mutationPayload = DataManager.MutationPayload(
            operation: "update",
            arrayOperation: "",
            collection: entity,
            data: dataToUpdate
        )
        
        print("Calling dataManager.mutate with payload: \(mutationPayload)")
        
        dataManager.mutate(payload: mutationPayload) { result in
            switch result {
                case .success():
                    print("Successfully set favorite for itemId: \(itemId)")
                case .failure(let error):
                    print("Error in setFavorite for itemId \(itemId): \(error.localizedDescription)")
            }
        }
    }

}
