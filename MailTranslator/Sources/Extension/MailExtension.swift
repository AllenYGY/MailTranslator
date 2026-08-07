import MailKit

final class MailExtension: NSObject, MEExtension {
    func handlerForMessageSecurity() -> MEMessageSecurityHandler {
        SecurityHandler.shared
    }
}
