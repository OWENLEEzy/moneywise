import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.deeplinkRouter) private var deeplinkRouter

    @State private var selectedTab = Tab.home
    @State private var showingManualSheet = false
    @State private var showingAISheet = false
    @State private var toastMessage: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView(showManualSheet: $showingManualSheet, showAISheet: $showingAISheet, toastMessage: $toastMessage)
                    .tabItem { Label("首页", systemImage: "house.fill") }
                    .tag(Tab.home)

                AssistantView()
                    .tabItem { Label("助手", systemImage: "bubble.left.and.right.fill") }
                    .tag(Tab.assistant)

                TransactionsView()
                    .tabItem { Label("明细", systemImage: "list.bullet.rectangle") }
                    .tag(Tab.transactions)

                ReportsView()
                    .tabItem { Label("报表", systemImage: "chart.pie.fill") }
                    .tag(Tab.reports)

                GoalsView()
                    .tabItem { Label("目标", systemImage: "target") }
                    .tag(Tab.goals)

                SettingsView()
                    .tabItem { Label("设置", systemImage: "gearshape.fill") }
                    .tag(Tab.settings)
            }
            .onReceive(NotificationCenter.default.publisher(for: .showAssistant)) { _ in
                selectedTab = .assistant
            }

            if selectedTab != .assistant {
                FloatingButtonBar(showManualSheet: $showingManualSheet, showAISheet: $showingAISheet)
            }
        }
        .sheet(isPresented: $showingManualSheet) {
            ManualEntrySheet(toastMessage: $toastMessage)
                .modelContext(context)
        }
        .sheet(isPresented: $showingAISheet) {
            AISmartEntrySheet(toastMessage: $toastMessage)
                .modelContext(context)
        }
        .overlay(alignment: .top) {
            if let message = toastMessage {
                ToastView(message: message) {
                    toastMessage = nil
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 40)
            }
        }
        .task {
            await handleDeepLinkIfNeeded()
        }
    }

    private func handleDeepLinkIfNeeded() async {
        guard let route = deeplinkRouter.pendingRoute else { return }
        switch route {
        case .aiAssistant:
            selectedTab = .assistant
        case .manualEntry:
            showingManualSheet = true
        case .goal:
            selectedTab = .goals
        case .settings:
            selectedTab = .settings
        }
        await MainActor.run {
            deeplinkRouter.pendingRoute = nil
        }
    }
}

extension ContentView {
    enum Tab: Hashable {
        case home, transactions, reports, goals, assistant, settings
    }
}