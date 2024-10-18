import Foundation

import SwiftUI
import GRDB
import Combine

public class AppManager: ObservableObject {
    @Published public var checkingAuth = false
    @Published public var isLoginRequired = false
    @Published public var isAuthenticated = false
    @Published public var isSyncing = false
    
    public var hasStartedStartupSequence = false
    
    @Published public var userName: String = "sagar"
    
    @Published public var collections: [Collection] = []
    @Published public var tags: [Tag] = []
    @Published public var settings:UserSettings = UserSettings(dock:
                                                                DockSettings(size: 1)
                                                                , sidebar: SidebarSettings(position: "left", size: 10))
    
    @Published public var verificationToken: String? = ""
    @Published public var email: String? = "benny@gmail.com"
    
    @Published public var bottomNavigation: [String] = ["Dashboard", "Home", "Settings"]
    @Published public var defaultView:String = "Settings"
    
    @Published public var language: String = "hi"
    @Published public var translations: [String: Translation] = [:]
    
    private let apiManager:APIManager
    private let dbManager: DBManager
    
    private var authManager: AuthManager!
    private var uiManager: UiManager!
    private var dataManager:DataManager!
    
    public var settingsPageData:SettingsPage?
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        print("AppManager: Initializing")
        self.dbManager = DBManager()
        self.apiManager = APIManager.shared
        
        let baseURL = URL(string: "https://cherrypic-in-uat-api.fly.dev")!
        self.apiManager.setBaseURL(baseURL)
        
        print("AppManager: DatabaseManager accessed")
        
        self.settingsPageData=nil
        

        setupAuthManager()
        setupUiManager()
        setUpDataManager()
        
        loadSettingsPageData()
        
        if let languageCode = Locale.current.language.languageCode?.identifier {
            self.language = languageCode
        }
        print("Device language set to: \(self.language)")
        print("All preferred languages: \(Locale.preferredLanguages)")
        
        setupLanguage()
        
        self.checkingAuth = true
        authManager.startupSequence()
    }
    
    private func setupLanguage() {
            // Get the preferred languages list
        let preferredLanguages = Locale.preferredLanguages
        
            // Check if Hindi is in the preferred languages list
        if let hindiCode = preferredLanguages.first(where: { $0.starts(with: "hi") }) {
            self.language = "hi"
            print("Hindi found in preferred languages: \(hindiCode)")
        } else if let firstLanguage = preferredLanguages.first,
                  let languageCode = Locale(identifier: firstLanguage).language.languageCode?.identifier {
            self.language = languageCode
            print("First preferred language: \(firstLanguage), setting language to: \(languageCode)")
        } else {
            print("Unable to determine language, defaulting to English")
        }
        
        print("Device language set to: \(self.language)")
        
        loadLanguageData()
    }

    
    private func setupAuthManager() {
        self.authManager = AuthManager(appManager: self)
    }
    
    private func setUpDataManager(){
        self.dataManager = DataManager()
    }
    
    private func setupUiManager(){
        self.uiManager = UiManager()
    }
    
    public func loadLanguageData() {
        let fileName = "\(language).json"
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
            print("Failed to locate \(fileName) in bundle.")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            self.translations = try decoder.decode([String: Translation].self, from: data)
            print("Loaded \(fileName) from bundle.")
        } catch {
            print("Failed to decode \(fileName) from bundle: \(error)")
        }
    }
    
    public func loadSettingsPageData() -> SettingsPage? {
        let fileName = "settings-page.json"
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
            print("Failed to locate \(fileName) in bundle.")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let settingsPage = try decoder.decode(SettingsPage.self, from: data)
            self.settingsPageData = settingsPage
            print("Loaded \(fileName) from bundle.")
            return settingsPage
        } catch {
            print("Failed to decode \(fileName) from bundle: \(error)")
            return nil
        }
    }
    
    public func translate(_ key: String) -> String {
        return translations[key]?.name ?? key
    }
    
    public func setBottomNavigationSequence(){
        self.bottomNavigation = ["Home", "Dashboard", "Settings"]
    }
    
    public func setSettingInState(path: String, value: Any) {
        do {
            print("setting state\(path)")
                // Build nested dictionary from path and value
            let partialData = buildNestedDictionary(path: path, value: value)
            
                // Convert partialData to JSON data
            let jsonData = try JSONSerialization.data(withJSONObject: partialData, options: [])
            
                // Decode JSON data into PartialUserSettings
            let decoder = JSONDecoder()
            let partialSettings = try decoder.decode(PartialUserSettings.self, from: jsonData)
            
                // Get the current settings (you need to fetch this from your storage or state)
            var currentSettings = self.settings
            
                // Merge partialSettings into currentSettings
            currentSettings.merge(with: partialSettings)
            
                // Serialize updated settings
            let encoder = JSONEncoder()
//            let updatedSettingsData = try encoder.encode(currentSettings)
            
                // Save updatedSettingsData to your storage or database
            self.settings  = currentSettings
            
                // Prepare mutation payload
            let result = partialData
            let mutationPayload = DataManager.MutationPayload(
                operation: "update",
                arrayOperation: "",
                collection: "settings",
                data: result
            )
            
            print("Calling dataManager.mutate with payload: \(mutationPayload)")
            
            dataManager.mutate(payload: mutationPayload) { result in
                switch result {
                    case .success():
                        print("Successfully updated settings")
                    case .failure(let error):
                        print("Error updating settings: \(error.localizedDescription)")
                }
            }
        } catch {
            print("Error in setSettingInState: \(error.localizedDescription)")
        }
    }
    
    func buildNestedDictionary(path: String, value: Any) -> [String: Any] {
        let components = path.split(separator: ".").map { String($0) }
        return components.reversed().reduce(value) { partialResult, key in
            [key: partialResult]
        } as! [String: Any]
    }

    func convertPathToNestedDictionary(path: String, value: Any) -> [String: Any] {
        let components = path.split(separator: ".").reversed()
        var currentValue: Any = value
        for component in components {
            let key = String(component)
            currentValue = [key: currentValue]
        }
        if let result = currentValue as? [String: Any] {
            return result
        } else {
            return [:]
        }
    }
    

    private func setCollections(_ newCollections: [Collection]) {
        DispatchQueue.main.async {
            self.collections = newCollections
        }
    }
    
    public func loadCoreData() {
        observeCollections()
        observeTags()
        observeSettings()
    }
    
    private func observeCollections() {
        dbManager.observeCollections()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        print("AppManager: Failed to observe collections - \(error)")
                    }
                },
                receiveValue: { [weak self] collections in
                    self?.collections = collections
                    print("AppManager: Collections updated, count: \(collections.count)")
                }
            )
            .store(in: &cancellables)
    }
    
    private func observeSettings() {
        dbManager.observeSettings()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        print("AppManager: Failed to observe settings - \(error)")
                    }
                },
                receiveValue: { [weak self] settings in
                    if let settings = settings {
                        do {
                            self?.settings = try settings.userSettings()
                            print("AppManager: Settings updated")
                        } catch {
                            print("AppManager: Failed to parse user settings - \(error)")
                                // Handle the error appropriately, e.g., set default settings or show an error to the user
                        }
                    } else {
                        print("AppManager: No settings found")
                            // Handle the case when no settings are found, e.g., create default settings
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func observeTags() {
        dbManager.observeTags()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        print("AppManager: Failed to observe tags - \(error)")
                    }
                },
                receiveValue: { [weak self] tags in
                    self?.tags = tags
                    print("AppManager: Tags updated, count: \(tags.count)")
                }
            )
            .store(in: &cancellables)
    }
    
    public func handleAction(_ action: String, payload: Any? = nil) {
        print("handleAction\(action)")
        switch action {
            case "setFavorite":
                print("Calling setFavorite with payload: \(String(describing: payload))")
                uiManager.setFavorite(payload: payload as Any)
            case "initiateEmailBasedLogin":
                authManager.initiateEmailBasedLogin { success in
                    if success {
                        print("Email-based login initiated successfully")
                    } else {
                        print("Failed to initiate email-based login")
                    }
                }
            case "verifyEmailBasedLogin":
                authManager.verifyEmailBasedLogin { success in
                    if success {
                        print("Email-based login verified successfully")
                    } else {
                        print("Failed to verify email-based login")
                    }
                }
            case "updateEmail":
                if let newEmail = payload as? String {
                    self.email = newEmail
                }
            case "updateVerificationToken":
                if let newVerificanToken = payload as? String {
                    self.verificationToken = newVerificanToken
                }
            case "startUpSequence":
                authManager.startupSequence()
            case "logout":
                authManager.logout()
            default:
                print("Unknown action: \(action)")
        }
    }
}
