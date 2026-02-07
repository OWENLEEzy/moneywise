import Foundation
import Combine

final class DeeplinkRouter: ObservableObject {
    enum Route {
        case aiAssistant
        case manualEntry
        case goal
        case settings
    }

    @Published var pendingRoute: Route?

    func handleURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "moneywise",
              let host = components.host else {
            return false
        }

        switch host {
        case "ai":
            pendingRoute = .aiAssistant
        case "manual":
            pendingRoute = .manualEntry
        case "goal":
            pendingRoute = .goal
        case "settings":
            pendingRoute = .settings
        default:
            return false
        }
        return true
    }
}
