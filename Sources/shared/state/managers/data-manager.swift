import Foundation

class DataManager {
    private let apiManager: APIManager
    private let dbManager: DBManager
    
    public init() {
        self.apiManager = APIManager.shared
        self.dbManager = DBManager()
    }
    
    public struct MutationPayload {
        let operation: String
        let arrayOperation: String?
        let collection: String
        let data: [String: Any]
    }
    
    public func mutate(payload: MutationPayload, completion: @escaping (Result<Void, Error>) -> Void) {
        
        var modifiedData = payload.data

        let dbPayload = DBManager.DBMutationPayload(
            operation: payload.operation,
            arrayOperation: payload.arrayOperation,
            collection: payload.collection,
            data: payload.data
        )
        
        let apiPayload = APIManager.APIMutationPayload(
            operation: payload.operation,
            arrayOperation: payload.arrayOperation,
            collection: payload.collection,
            data: modifiedData,
            clientId: "123"
        )
        
        do {
            try dbManager.mutate(payload: dbPayload)
            
            apiManager.mutate(payload: apiPayload) { result in
                switch result {
                    case .success(_):
                        completion(.success(()))
                    case .failure(let error):
                        completion(.failure(error))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
}
