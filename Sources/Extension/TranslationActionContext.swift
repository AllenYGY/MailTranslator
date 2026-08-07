import Foundation

/// The exact banner action that Mail rendered for a message presentation.
struct TranslationActionContext: Codable, Equatable {
    enum Action: String, Codable {
        case start
        case stop
        case continueTranslation
        case retranslate
        case retry
        case showOriginal
        case showBilingual
    }

    let key: String
    let token: UInt
    let action: Action

    init(key: String, token: UInt, action: Action) {
        self.key = key
        self.token = token
        self.action = action
    }

    init?(data: Data) {
        guard let decoded = try? JSONDecoder().decode(Self.self, from: data) else {
            return nil
        }
        self = decoded
    }

    var dataRepresentation: Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }
}
