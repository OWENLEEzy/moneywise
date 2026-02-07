import SwiftUI
import SwiftData

struct GeneralSettingsView: View {
    @Environment(\.modelContext) private var context
    @ObservedObject private var languageManager = LanguageManager.shared

    // Notification settings
    @State private var dailyReminderEnabled = false
    @State private var reminderTime = Calendar.current.date(from: DateComponents(hour: 21, minute: 0)) ?? Date()

    @State private var weeklyGoalEnabled = false
    @State private var weeklyGoalDay: Int = 2 // Monday
    @State private var weeklyGoalTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()

    var body: some View {
        Form {
            Section(header: Text("主题 / Theme".localized)) {
                ThemePickerView()
            }

            Section(header: Text("Notifications".localized)) {
                // Daily Reminder
                Toggle(isOn: Binding(
                    get: { dailyReminderEnabled },
                    set: { handleDailyReminderToggle(enabled: $0) }
                )) {
                    VStack(alignment: .leading) {
                        Text("Daily Log Reminder".localized)
                        Text("Get reminded to log your expenses".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if dailyReminderEnabled {
                    DatePicker("Reminder Time".localized, selection: Binding(
                        get: { reminderTime },
                        set: { handleReminderTimeChange(time: $0) }
                    ), displayedComponents: .hourAndMinute)
                }

                // Weekly Goal Progress
                Toggle(isOn: Binding(
                    get: { weeklyGoalEnabled },
                    set: { handleWeeklyGoalToggle(enabled: $0) }
                )) {
                    VStack(alignment: .leading) {
                        Text("Weekly Goal Progress".localized)
                        Text("Track your savings progress".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if weeklyGoalEnabled {
                    Picker("Day of Week".localized, selection: Binding(
                        get: { weeklyGoalDay },
                        set: {
                            weeklyGoalDay = $0
                            handleWeeklySettingsChange()
                        }
                    )) {
                        Text("Monday".localized).tag(2)
                        Text("Tuesday".localized).tag(3)
                        Text("Wednesday".localized).tag(4)
                        Text("Thursday".localized).tag(5)
                        Text("Friday".localized).tag(6)
                        Text("Saturday".localized).tag(7)
                        Text("Sunday".localized).tag(1)
                    }

                    DatePicker("Time".localized, selection: Binding(
                        get: { weeklyGoalTime },
                        set: {
                            weeklyGoalTime = $0
                            handleWeeklySettingsChange()
                        }
                    ), displayedComponents: .hourAndMinute)
                }
            }

            Section(header: Text("Language".localized)) {
                Picker("Language".localized, selection: $languageManager.selectedLanguageCode) {
                    ForEach(Language.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }

            Section(header: Text("About".localized)) {
                HStack {
                    Text("AI Model".localized)
                    Spacer()
                    Text("Gemini 2.5 Flash")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Version".localized)
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("General Settings".localized)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadNotificationSettings()
        }
    }

    // MARK: - Notification Methods

    private func loadNotificationSettings() {
        // Load from UserDefaults
        dailyReminderEnabled = UserDefaults.standard.bool(forKey: "dailyReminderEnabled")
        if let savedTime = UserDefaults.standard.object(forKey: "reminderTime") as? Date {
            reminderTime = savedTime
        }

        weeklyGoalEnabled = UserDefaults.standard.bool(forKey: "weeklyGoalEnabled")
        weeklyGoalDay = UserDefaults.standard.integer(forKey: "weeklyGoalDay")
        if weeklyGoalDay == 0 { weeklyGoalDay = 2 } // Default to Monday
        if let savedGoalTime = UserDefaults.standard.object(forKey: "weeklyGoalTime") as? Date {
            weeklyGoalTime = savedGoalTime
        }
    }

    private func handleDailyReminderToggle(enabled: Bool) {
        Task {
            if enabled {
                let scheduler = NotificationScheduler()
                let granted = await scheduler.requestAuthorization()

                await MainActor.run {
                    if granted {
                        dailyReminderEnabled = true
                        UserDefaults.standard.set(true, forKey: "dailyReminderEnabled")
                        scheduleDaily()

                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    } else {
                        dailyReminderEnabled = false
                        UserDefaults.standard.set(false, forKey: "dailyReminderEnabled")
                    }
                }
            } else {
                NotificationScheduler().cancelDailyReminder()
                UserDefaults.standard.set(false, forKey: "dailyReminderEnabled")

                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }

    private func handleWeeklyGoalToggle(enabled: Bool) {
        Task {
            if enabled {
                let scheduler = NotificationScheduler()
                let granted = await scheduler.requestAuthorization()

                await MainActor.run {
                    if granted {
                        weeklyGoalEnabled = true
                        UserDefaults.standard.set(true, forKey: "weeklyGoalEnabled")
                        scheduleWeekly()

                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    } else {
                        weeklyGoalEnabled = false
                        UserDefaults.standard.set(false, forKey: "weeklyGoalEnabled")
                    }
                }
            } else {
                NotificationScheduler().cancelWeeklyGoalReminder()
                UserDefaults.standard.set(false, forKey: "weeklyGoalEnabled")

                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }

    private func scheduleDaily() {
        Task {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: reminderTime)
            await NotificationScheduler().scheduleDailyReminder(
                at: components,
                body: "How was your day? Don't forget to log your expenses."
            )
        }
    }

    private func scheduleWeekly() {
        Task {
            // Fetch goals to calculate progress
            let descriptor = FetchDescriptor<Goal>()
            if let goals = try? context.fetch(descriptor) {
                await NotificationScheduler().scheduleWeeklyGoalReminder(
                    dayOfWeek: weeklyGoalDay,
                    time: weeklyGoalTime,
                    goals: goals
                )
            }
        }
    }

    private func handleReminderTimeChange(time: Date) {
        UserDefaults.standard.set(time, forKey: "reminderTime")
        if dailyReminderEnabled {
            scheduleDaily()
        }
    }

    private func handleWeeklySettingsChange() {
        UserDefaults.standard.set(weeklyGoalDay, forKey: "weeklyGoalDay")
        UserDefaults.standard.set(weeklyGoalTime, forKey: "weeklyGoalTime")
        if weeklyGoalEnabled {
            scheduleWeekly()
        }
    }
}

#Preview {
    NavigationStack {
        GeneralSettingsView()
            .modelContainer(for: Goal.self, inMemory: true)
    }
}
