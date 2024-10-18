import Foundation
import LDSwiftEventSource

class EventStreamManager {
    private var eventSource: EventSource?
    private var clientId: String = ""
    private let baseURL: URL
    
    private let dbManager = DBManager()
    
    init(baseURL: URL) {
        self.baseURL = baseURL
    }
    
    func initEventStream() {
        clientId = UUID().uuidString.lowercased()
        let urlString = "\(baseURL.absoluteString)/event-stream?clientId=\(clientId)"
        
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        
        var headers: [String: String] = [:]
        if let sessionIdData = KeychainManager.load(key: "sessionId"),
           let sessionId = String(data: sessionIdData, encoding: .utf8) {
            headers["Authorization"] = "Bearer \(sessionId)"
        }
        
        var config = EventSource.Config(handler: self, url: url)
        config.headers = headers
        
        eventSource = EventSource(config: config)
        eventSource?.start()
    }
    
    private func processEventStream(data: String) {
        print("Entering processEventStream")
        print("Received data: \(data)")
        
            
            // The data is already JSON, so we can pass it directly to processEventData
        processEventData(jsonData: data)
        
        print("Exiting processEventStream")
    }
    
    private func processEventData(jsonData: String) {
        print("Entering processEventData")
        print("Received JSON data: \(jsonData)")
        
        guard let eventData = jsonData.data(using: .utf8),
              let message = try? JSONSerialization.jsonObject(with: eventData, options: []) as? [String: Any] else {
            print("Failed to parse JSON data")
            return
        }
        
        print("Parsed message: \(message)")
        
        if let type = message["type"] as? String, type == "welcome" {
            print("Set up event stream")
            return
        }
        
        guard let messageClientId = message["clientId"] as? String,
              messageClientId != clientId else {
            print("Ignoring changes from own client")
            return
        }
        
        let collection = message["collection"] as? String ?? ""
        let operation = message["operation"] as? String ?? ""
        let data = message["data"] as? [String: Any] ?? [:]
        let syncId = message["syncId"] as? String ?? ""
        let arrayOperation = (data["arrayOperation"] as? String) ?? ""
        
        do {
            let mutationPayload = DBManager.DBMutationPayload(
                operation: operation,
                arrayOperation: arrayOperation,
                collection: collection,
                data: data
            )
            
            do {
                try dbManager.mutate(payload: mutationPayload)
            } catch {
                print("Error: \(error)")
            }
            print("Changes applied and syncId updated to \(syncId)")
        } catch {
            print("Error applying changes: \(error.localizedDescription)")
        }
        
        print("Exiting processEventData")
    }   
    
    func stopEventStream() {
        eventSource?.stop()
    }
}

extension EventStreamManager: EventHandler {
    func onOpened() {
        print("Event stream connected")
    }
    
    func onClosed() {
        print("Event stream closed")
    }
    
    func onMessage(eventType: String, messageEvent: LDSwiftEventSource.MessageEvent) {
        print("Received event: \(eventType), data: \(messageEvent.data)")
            // Handle your event data here
        processEventStream(data: messageEvent.data)
    }
    
    func onComment(comment: String) {
        print("Received comment: \(comment)")
    }
    
    func onError(error: Error) {
        print("Event stream error: \(error.localizedDescription)")
    }
}
