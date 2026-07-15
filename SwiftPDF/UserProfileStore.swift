import Combine
import Foundation
import os

struct UserProfile: Codable {
    var fullName: String = ""
    var email: String = ""
    var phone: String = ""
    var address: String = ""
}

@MainActor
final class UserProfileStore: ObservableObject {
    @Published var profile: UserProfile = UserProfile()
    private let saveKey = "SwiftPDF_UserProfile"
    private let logger = Logger(subsystem: "JimWas.SwiftPDF", category: "UserProfileStore")

    static let shared = UserProfileStore()

    private init() {
        load()
    }

    func save() {
        do {
            let encoded = try JSONEncoder().encode(profile)
            UserDefaults.standard.set(encoded, forKey: saveKey)
        } catch {
            logger.error("Failed to encode user profile: \(error.localizedDescription)")
        }
    }

    func clear() {
        profile = UserProfile()
        UserDefaults.standard.removeObject(forKey: saveKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else {
            return
        }

        do {
            profile = try JSONDecoder().decode(UserProfile.self, from: data)
        } catch {
            logger.error("Failed to decode user profile: \(error.localizedDescription)")
        }
    }
}
