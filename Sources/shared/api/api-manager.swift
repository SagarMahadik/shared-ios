import Foundation
import Combine

class APIManager {
    static let shared =  APIManager()
    private var apiClient: APIClient?
    private let dbManager = DBManager()
    private var eventStreamStatus: String = "disconnected"
    private var clientId: String = ""
    
    private var eventStreamManager: EventStreamManager?
    
    private var cancellables = Set<AnyCancellable>()
        
    func setBaseURL(_ baseURL: URL) {
        self.apiClient = APIClient(baseURL: baseURL)
        self.eventStreamManager = EventStreamManager(baseURL: baseURL)
    }
    
    public func initEventStream(clientId:String) {
        eventStreamManager!.initEventStream()
    }
    
    func login(params: LoginRequest, completion: @escaping (Result<(LoginData, String), Error>) -> Void) {
        let body: [String: Any] = ["operation": params.operation, "data": params.data]
        
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body, options: []) else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not encode body"])))
            return
        }
        
        apiClient!.api(method: "POST", path: "/login", body: bodyData) { result in
            switch result {
                case .success(let response):
                    guard let data = response.data else {
                        completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                        return
                    }
                    do {
                        let decoder = JSONDecoder()
                        let loginResponse = try decoder.decode(LoginResponse.self, from: data)
                        
                        completion(.success((loginResponse.data, loginResponse.status)))
                    } catch {
                        completion(.failure(error))
                    }
                case .failure(let error):
                    completion(.failure(error))
            }
        }
    }
    
    func getUser(completion: @escaping (Result<UserData, Error>) -> Void) {
        apiClient?.api(method: "GET", path: "/get-user") { result in
            switch result {
                case .success(let response):
                    guard let data = response.data else {
                        completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                        return
                    }
                    do {
                        let decoder = JSONDecoder()
                        let getUserResponse = try decoder.decode(GetUserResponse<UserData>.self, from: data)
                        print("userData: \(getUserResponse.data)")
                        completion(.success(getUserResponse.data))
                    } catch {
                        completion(.failure(error))
                    }
                case .failure(let error):
                    completion(.failure(error))
            }
        }
    }
    
    public struct APIMutationPayload {
        let operation: String
        let arrayOperation: String?
        let collection: String
        let data: [String: Any]
        let clientId:String
    }
    
    func mutate(payload: APIMutationPayload, completion: @escaping (Result<Data, Error>) -> Void) {
        var body: [String: Any] = [
            "operation": payload.operation,
            "collection": payload.collection,
            "data": payload.data
        ]
        
        if let arrayOperation = payload.arrayOperation {
            body["arrayOperation"] = arrayOperation
        }
        
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body, options: []) else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not encode body"])))
            return
        }
        
        apiClient?.api(method: "POST", path: "/mutate", body: bodyData) { result in
            switch result {
                case .success(let response):
                    guard let data = response.data else {
                        completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                        return
                    }
                    completion(.success(data))
                case .failure(let error):
                    completion(.failure(error))
            }
        }
    }
    
    func fullBootstrap(completion: @escaping (Result<BootstrapData, Error>) -> Void) {
        apiClient?.api(method: "GET", path: "/full-bootstrap") { result in
            switch result {
                case .success(let response):
                    guard let data = response.data else {
                        completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                        return
                    }
                    do {
                        let decoder = JSONDecoder()
                        let fullBootstrapResponse = try decoder.decode(FullBootstrapResponse.self, from: data)
                        print("Bootstrap data fetched successfully")
                        completion(.success(fullBootstrapResponse.data))
                    } catch {
                        completion(.failure(error))
                    }
                case .failure(let error):
                    completion(.failure(error))
            }
        }
    }
    
    func deltaSync(fromSyncId: Int, toSyncId: Int, completion: @escaping (Result<DeltaSyncData, Error>) -> Void) {
        let request = DeltaSyncRequest(data: .init(fromSyncId: fromSyncId, toSyncId: toSyncId))
        
        do {
            let encoder = JSONEncoder()
            let requestData = try encoder.encode(request)
            
            apiClient?.api(method: "POST", path: "/delta-sync", body: requestData) { result in
                switch result {
                    case .success(let response):
                        guard let data = response.data else {
                            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                            return
                        }
                        do {
                            let decoder = JSONDecoder()
                            let deltaSyncResponse = try decoder.decode(DeltaSyncResponse.self, from: data)
                            print("Delta sync data fetched successfully")
                            completion(.success(deltaSyncResponse.data))
                        } catch {
                            completion(.failure(error))
                        }
                    case .failure(let error):
                        completion(.failure(error))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    func streamData(completion: @escaping (Result<Void, Error>) -> Void) {
        print("Stream reading started")
        
        apiClient?.api(method: "GET", path: "/stream-data", body: nil) { result in
            switch result {
                case .success(let response):
                    guard let data = response.data else {
                        completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                        return
                    }
                    self.processStreamData(data: data, completion: completion)
                case .failure(let error):
                    completion(.failure(error))
            }
        }
    }
    
    private func processStreamData(data: Data, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            if let string = String(data: data, encoding: .utf8) {
                let lines = string.components(separatedBy: .newlines)
                
                var bookmarks: [Bookmark] = []
                var highlights: [Highlight] = []
                
                for line in lines {
                    if !line.isEmpty {
                        
                        guard let data = line.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let type = json["type"] as? String,
                              let innerData = json["data"] as? [String: Any] else {
                            continue
                        }
                        
                        switch type {
                            case "bookmarks":
                                if let bookmark = self.parseBookmark(from: innerData) {
                                    bookmarks.append(bookmark)
                                }
                            case "highlights":
                                if let highlight = self.parseHighlight(from: innerData) {
                                    highlights.append(highlight)
                                }
                            default:
                                print("Unknown type: \(type)")
                        }
                    }
                }
                
                print("Stream reading completed")
                print("Bookmarks to insert: \(bookmarks.count)")
                print("Highlights to insert: \(highlights.count)")
                
                do {
                    try self.dbManager.bulkInsert(bookmarks)
                    try self.dbManager.bulkInsert(highlights)
                    completion(.success(()))
                } catch {
                    print("Error during bulk insert: \(error)")
                    completion(.failure(error))
                }
            } else {
                let error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to decode data as UTF-8"])
                completion(.failure(error))
            }
        }
    }
    
    private func parseBookmark(from dict: [String: Any]) -> Bookmark? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [])
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let bookmark = try decoder.decode(Bookmark.self, from: jsonData)
            return bookmark
        } catch {
            print("Error parsing bookmark: \(error)")
            return nil
        }
    }
    
    private func parseHighlight(from dict: [String: Any]) -> Highlight? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [])
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let highlight = try decoder.decode(Highlight.self, from: jsonData)
            return highlight
        } catch {
            print("Error parsing highlight: \(error)")
            return nil
        }
    }
}



struct LoginRequest {
    let operation: String
    let data: [String: Any]
}

struct LoginResponse: Codable {
    let data: LoginData
    let status: String
}

struct LoginData: Codable {
    let verificationToken: String?
    let sessionId: String?
    let additionalData: [String: String]?
}

struct GetUserResponse<T: Codable>: Codable {
    let data: T
}

struct UserData: Codable {
    let profile: User
    let settings: UserSettings
    let syncId: Int
}

struct User: Codable {
    let _id: String
    let email: String
    let syncId: Int
    let userId: String
}

struct FullBootstrapResponse: Codable {
    let data: BootstrapData
}

struct BootstrapData: Codable {
    let collections: [Collection]
    let tags: [Tag]
}

struct DeltaSyncRequest: Codable {
    let data: RequestData
    
    struct RequestData: Codable {
        let fromSyncId: Int
        let toSyncId: Int
    }
}
    // Response structures
struct DeltaSyncResponse: Codable {
    let data: DeltaSyncData
}

struct DeltaSyncData: Codable {
    let count: Int
    let syncRecords: [SyncRecord]
}

struct SyncRecord: Codable {
    let data: String // This is likely JSON data, you might want to parse it further
    let collection: String
    let operation: String
    let arrayOperation: String?
    let userId: String
    let updatedAt: String
    let syncId: Int
    let _id: String
    let ver: Int?
}
