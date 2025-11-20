import SwiftUI
import SwiftData

struct GoalManagerKey: EnvironmentKey {
    static let defaultValue: GoalManager? = nil
}

struct AIConfigurationStoreKey: EnvironmentKey {
    static let defaultValue: AIConfigurationStore? = nil
}

struct DeeplinkRouterKey: EnvironmentKey {
    static let defaultValue = DeeplinkRouter()
}

extension EnvironmentValues {
    var managedGoals: GoalManager? {
        get { self[GoalManagerKey.self] }
        set { self[GoalManagerKey.self] = newValue }
    }

    var aiConfiguration: AIConfigurationStore? {
        get { self[AIConfigurationStoreKey.self] }
        set { self[AIConfigurationStoreKey.self] = newValue }
    }

    var deeplinkRouter: DeeplinkRouter {
        get { self[DeeplinkRouterKey.self] }
        set { self[DeeplinkRouterKey.self] = newValue }
    }
}

