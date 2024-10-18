import Foundation

class APIClient {
    static let shared = APIClient()
    let baseURL: URL
    
    init(baseURL: URL = URL(string: "https://cherrypic-in-uat-api.fly.dev")!) {
        self.baseURL = baseURL
    }
        
    func api(method: String, path: String,  body: Data? = nil, completion: @escaping (Result<(data: Data?, responseCode: Int), Error>) -> Void) {
        
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("MOBILE-ANDROID", forHTTPHeaderField: "X-App-Source")
        if method != "GET" {
            request.httpBody = body
        }
        
        if let sessionIdData = KeychainManager.load(key: "sessionId"),
           let sessionId = String(data: sessionIdData, encoding: .utf8) {
           print("session id found\(sessionId)")
            request.setValue("Bearer \(sessionId)", forHTTPHeaderField: "Authorization")
        } else {
            print("session id not found")
                 request.setValue("", forHTTPHeaderField: "Authorization")
        }
        
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(error ?? URLError(.badServerResponse)))
                    return
                }
                
                guard httpResponse.statusCode == 200 else {
                    completion(.failure(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP error! Status: \(httpResponse.statusCode)"])))
                    return
                }
                
                completion(.success((data, httpResponse.statusCode)))
            }
        }.resume()
    }
}
