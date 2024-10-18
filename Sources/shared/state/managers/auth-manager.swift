import Foundation
import Combine

class AuthManager {
    private let apiManager: APIManager
    private let dbManager: DBManager
    private unowned let appManager: AppManager
    
    private var cancellables = Set<AnyCancellable>()
    
    public init(appManager: AppManager) {
        self.apiManager = APIManager.shared
        self.appManager = appManager
        self.dbManager = DBManager()
    }
    
    func initiateEmailBasedLogin(completion: @escaping (Bool) -> Void) {
        guard let email = self.appManager.email else {
            completion(false)
            return
        }
        
        let data: [String: Any] = [
            "email": email,
            "clientAuthCode": "1234567890"
        ]
        
        let loginRequest = LoginRequest(operation: "initiateEmailBasedLogin", data: data)
        
        apiManager.login(params: loginRequest) { [weak self] (result: Result<(LoginData, String), Error>) in
            switch result {
                case .success(let (data, status)):
                    if status == "success" {
                        if let token = data.verificationToken {
                            self?.appManager.verificationToken = token
                            completion(true)
                        }
                    } else if status == "error" {
                        print("Login Error - Display back to login button")
                        completion(false)
                    }
                case .failure(let error):
                    print("Login failed with error: \(error)")
                    completion(false)
            }
        }
    }
    
    func verifyEmailBasedLogin(completion: @escaping (Bool) -> Void) {
        guard let email = appManager.email,
              let verificationToken = appManager.verificationToken else {
            completion(false)
            return
        }
        
        let data: [String: Any] = [
            "email": email,
            "verificationToken": verificationToken
        ]
        
        let loginRequest = LoginRequest(operation: "verifyEmailBasedLogin", data: data)
        
        apiManager.login(params: loginRequest) { (result: Result<(LoginData, String), Error>) in
            switch result {
                case .success(let (data, status)):
                    if status == "success" {
                        if let sessionId = data.sessionId {
                            let sessionData = Data(sessionId.utf8)
                            let saveStatus = KeychainManager.save(key: "sessionId", data: sessionData)
                            if saveStatus == noErr {
                                print("Session ID stored successfully in Keychain")
                                
                                DispatchQueue.main.async {
                                    self.appManager.checkingAuth = false
                                    self.appManager.isLoginRequired = false
                                    self.startupSequence()
                                    self.appManager.isSyncing = true
                                }
                                                                
                                completion(true)
                                
                            } else {
                                print("Failed to store session ID in Keychain")
                                completion(false)
                            }
                        }
                    } else if status == "error" {
                        print("Login Error - Try login Error, error message from server")
                        completion(false)
                    }
                case .failure(let error):
                    print("Login failed with error: \(error)")
                    completion(false)
            }
        }
    }
    
func deltaSync(lastSyncId: Int, currentSyncId: Int) {
    apiManager.deltaSync(fromSyncId: lastSyncId, toSyncId: currentSyncId) { result in
        switch result {
        case .success(let deltaSyncData):
            print("Delta sync successful")
            print("Number of sync records: \(deltaSyncData.count)")
            
            let changes = deltaSyncData.syncRecords.compactMap { record -> DBManager.DBMutationPayload? in
                guard let data = try? JSONSerialization.jsonObject(with: record.data.data(using: .utf8) ?? Data(), options: []) as? [String: Any] else {
                    print("Failed to parse data for record: \(record)")
                    return nil
                }
                
                return DBManager.DBMutationPayload(
                    operation: record.operation,
                    arrayOperation: record.arrayOperation, 
                    collection: record.collection,
                    data: data
                )
            }
            
            do {
                try self.dbManager.applyDeltaChanges(changes: changes)
                print("Successfully applied delta changes to the database")
            } catch {
                print("Failed to apply delta changes to the database: \(error)")
            }
            
            for record in deltaSyncData.syncRecords {
                print("Synced item: Collection: \(record.collection), Operation: \(record.operation), SyncId: \(record.syncId), Data: \(record.data)")
            }
            
        case .failure(let error):
            print("Failed to perform delta sync with error: \(error)")
        }
    }
}
    
    func fullBootstrap(syncId:Int) {
        apiManager.fullBootstrap() { result in
            switch result {
                case .success(let bootstrapData):
                    print("Full bootstrap data fetched successfully")
                    print("Number of collections: \(bootstrapData.collections.count)")
                    print("Number of tags: \(bootstrapData.tags.count)")
                    
                    do {
                        try self.dbManager.bulkInsert(bootstrapData.tags)
                        print("Tags inserted successfully")
                        
                        try self.dbManager.bulkInsert(bootstrapData.collections)
                        print("Collections inserted successfully")
                                                
                        self.streamData(syncId: syncId)
                    } catch {
                        print("Failed to insert data into database: \(error)")
                    }
                    
                case .failure(let error):
                    print("Failed to get full bootstrap data with error: \(error)")
            }
        }
    }
    
    func streamData(syncId:Int) {
        apiManager.streamData { result in
            switch result {
                case .success():
                    print("Stream data processing completed")
                    do {
                        try self.dbManager.setSyncId(syncId)
                    } catch {
                        print("sync id could not be set up")
                    }
                    DispatchQueue.main.async {
                        self.appManager.isSyncing  = false
                        self.initializeEventStream()
                    }
                    
                case .failure(let error):
                    print("Error processing stream data: \(error)")
            }
        }
    }
    
    public func startupSequence() {
        
        apiManager.getUser() { result in
            switch result {
                case .success(let userData):
                    print("User data fetched successfully")
                    print("User ID: \(userData.profile._id)")
                    print("Email: \(userData.profile.email)")
                    print("Sync ID: \(userData.syncId)")
                    print("Proceed to fetch collections and tags")
                  
                    do {
                        let encoder = JSONEncoder()
                        let settingsData = try encoder.encode(userData.settings)
                        let settingsJson = try JSONSerialization.jsonObject(with: settingsData, options: []) as? [String: Any] ?? [:]
                        
                        let dataToSave: [String: Any] = [
                            "_id": "1",  // Always use "1" as the _id for settings
                            "userId": userData.profile._id,
                            "settings": settingsJson
                        ]
                        
                    try self.dbManager.create(collection: .settings, with: dataToSave)
                        print("User settings saved successfully")
                    } catch {
                        print("Failed to save user settings: \(error)")

                    }
                    
                    DispatchQueue.main.async {
                        self.appManager.checkingAuth = false
                        self.appManager.isLoginRequired = false
                        self.appManager.isAuthenticated = true
                        self.appManager.isSyncing = true
                    }
                    
                    let syncIdInServer = userData.syncId
                    var syncIdInLocal: Int?
                    do {
                        syncIdInLocal = try self.dbManager.getSyncId()
                        print("Existing Sync ID: \(syncIdInLocal)")
                    } catch {
                        
                        print("sync id not found")
                        self.fullBootstrap(syncId: syncIdInServer)
                    }
                    
                    if syncIdInLocal == nil || syncIdInLocal == 0 {
                        do {
                            try self.dbManager.clearAllData()
                            self.fullBootstrap(syncId: syncIdInServer)
                        } catch {
                           print("could not clear data")
                        }
                        
                    } else if syncIdInLocal == syncIdInServer {
                        DispatchQueue.main.async {
                            self.appManager.isSyncing  = false
                        }
                        self.initializeEventStream()
                    } else if let localId = syncIdInLocal, localId < syncIdInServer {
                        self.deltaSync(lastSyncId: localId, currentSyncId: syncIdInServer)
                        DispatchQueue.main.async {
                            self.appManager.isSyncing  = false
                        }
                        self.initializeEventStream()
                    } else {
                        print("Unexpected sync state. Local sync ID is greater than server sync ID.")
                        // Consider handling this case, perhaps with a full bootstrap
                        self.fullBootstrap(syncId: syncIdInServer)
                        self.initializeEventStream()
                    }
                    
                case .failure(let error):
                    print("Failed to get user details with error: \(error)")
                    print("Error - Display back to login button")
                    DispatchQueue.main.async {
                        self.appManager.checkingAuth = false
                        self.appManager.isLoginRequired = true
                        self.appManager.isAuthenticated = false
                    }
            }
        }
    }
    
    private func initializeEventStream() {
        
        let clientId = generateUniqueClientId()
                
        apiManager.initEventStream(clientId: clientId)
    }
    
    public func logout() {
        let sessionDeleted = KeychainManager.delete(key: "sessionId")
        if sessionDeleted {
            KeychainManager.logger.info("Session ID successfully deleted from Keychain")
        } else {
            KeychainManager.logger.error("Failed to delete Session ID from Keychain")
        }
        
        do {
            try self.dbManager.clearAllData()
            KeychainManager.logger.info("Database cleared successfully")
        } catch {
            KeychainManager.logger.error("Could not clear data: \(error.localizedDescription)")
        }
        
        DispatchQueue.main.async {
            self.appManager.checkingAuth = false
            self.appManager.isLoginRequired = true
            self.appManager.isAuthenticated = false
            KeychainManager.logger.info("App state updated: User logged out")
        }
    }
    
    private func generateUniqueClientId() -> String {
        return UUID().uuidString.lowercased()
    }
}
