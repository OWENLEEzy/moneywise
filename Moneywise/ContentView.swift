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
                    .toolbar(.hidden, for: .tabBar)
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(Tab.home)

                AssistantView()
                    .toolbar(.hidden, for: .tabBar)
                    .tabItem { Label("Assistant", systemImage: "bubble.left.and.right.fill") }
                    .tag(Tab.assistant)

                TransactionsView()
                    .toolbar(.hidden, for: .tabBar)
                    .tabItem { Label("Transactions", systemImage: "list.bullet.rectangle") }
                    .tag(Tab.transactions)

                ReportsView(selectedTab: $selectedTab)
                    .toolbar(.hidden, for: .tabBar)
                    .tabItem { Label("Reports", systemImage: "chart.pie.fill") }
                    .tag(Tab.reports)

                GoalsView(selectedTab: $selectedTab)
                    .toolbar(.hidden, for: .tabBar)
                    .tabItem { Label("Goals", systemImage: "target") }
                    .tag(Tab.goals)
            }
            .toolbar(.hidden, for: .tabBar)
            .onReceive(NotificationCenter.default.publisher(for: .showAssistant)) { _ in
                selectedTab = .assistant
            }

            if selectedTab != .assistant {
                FloatingButtonBar(showManualSheet: $showingManualSheet, showAISheet: $showingAISheet, selectedTab: $selectedTab)
            }
        }
        .ignoresSafeArea(.keyboard)
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
            // Settings is now accessed from Home, but we can't easily switch to it via tab.
            // For now, we'll switch to Home, and Home handles showing settings if needed?
            // Or we can just ignore deep link for settings or handle it differently.
            // Let's switch to home for now.
            selectedTab = .home
        }
        await MainActor.run {
            deeplinkRouter.pendingRoute = nil
        }
    }
}

extension ContentView {
    enum Tab: Hashable {
        case home, transactions, reports, goals, assistant
    }
}