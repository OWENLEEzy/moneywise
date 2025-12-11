## Architecture Layers

```
GemBudget
├── GemBudgetApp.swift        // SwiftData Container, Dependency Injection
├── Models/                   // @Model Data Structures, Environment Keys
├── ViewModels/               // Business State (GoalManager, AI Config, Routing)
├── Services/                 // AI/Keychain/CSV/Notification Logic
├── Views/                    // SwiftUI Pages (Grouped by IA)
└── Resources/                // Static Resources
```

- **UI**: Simplified `TabView` (Home, Transactions, Reports, Goals, Assistant). Settings accessed via Home View toolbar (top-right). Reports and Goals views feature a "Back" button to return to Home. `FloatingButtonBar` for quick navigation. All amounts use Coin Emoji 🪙. **Full English Interface**.
- **State**: Official `Observation` + `SwiftData`. `GoalManager`, `AIConfigurationStore` in Environment.
- **Data**: SwiftData auto-generates SQLite tables, using `@Model` for `Transaction/Goal/AIInsight...`; Full CSV Import/Export (`CSVService`+UI) with de-duplication.
- **AI**: `GeminiService` uses Gemini 2.5 Flash model. Token usage tracked and displayed in Settings.
- **Security**: Keychain stores API Key. Data stored locally in sandbox.
- **Reminders**: `NotificationScheduler` fully implemented for daily logging and goal deadlines.

## Key Workflows

### AI Speedy Entry
1. User taps the bottom center AI button (Brain Icon) to open `AISmartEntrySheet`.
2. **Text Input**: Type description directly, or **Voice Input**: Tap mic to record, `SFSpeechRecognizer` (English) transcribes to text.
3. `GeminiService` uses Gemini 2.5 Flash to parse into structured JSON.
4. Confirmation card appears with amount, category, date, etc.
5. **Confidence ≥ 0.8**: Auto-starts 3s countdown, cancelable; **< 0.8**: Warning shown, manual confirmation required.
6. Saved to SwiftData, Token usage recorded.

### CSV Import/Export
**Fully Implemented** (Backend + UI):
1. **Export**: Settings -> "Export Transactions" -> `CSVService.export()` generates CSV -> System Share Sheet.
2. **Import**: Settings -> "Import Transactions" -> Select CSV -> `CSVService.import()` parses -> Smart De-duplication -> Import Result Stats.

### Savings Goals
1. GoalsView click "+" -> `AddGoalSheet` form (Name, Amount, Date).
2. Saved to SwiftData, progress shown in `HomeView` and `GoalsView`.
3. Auto-schedules reminder 7 days before deadline.

### AI Reports & Insights
1. `ReportsView` displays spending trend chart (Last 7 Days / Last 30 Days).
2. **Period Selection**: Toggle between "This Week" and "This Month".
3. **AI Insights**:
    - Checks local `AIInsight` cache for the selected period.
    - If missing or requested, calls `AIService.generateInsights` (Gemini).
    - Displays Summary and Consumption Insights.
4. **AI Chat**: Click chat button to open conversational assistant for specific questions.

## Current Implementation Status

### ✅ Completed Core Features (100%)
- **AI Config**: Full API Key management (Input, Save, Test, Help, Usage Stats)
- **AI Entry**: Text & Voice input parsing, Gemini 2.5 Flash
- **Voice to Text**: Integrated SFSpeechRecognizer, English real-time transcription
- **3s Auto-Confirm**: Confidence-based countdown, cancelable
- **CSV Import/Export**: Full UI & Backend, Share, De-duplication
- **API Stats**: Token usage, Call count, Pricing link
- **Goal Management**: Create, List, Details, Progress tracking
- **Transactions**: Search, Filter (All/Expense/Income), Swipe delete
- **Reminders**: Daily & Goal reminders (Backend + UI)
- **Data Models**: Transaction, Goal, SpendingCategory, AIUsageStats, AIInsight
- **Storage**: SwiftData + Keychain
- **Reports**: Trend Chart, AI Weekly/Monthly Insights, AI Chat
- **UI Design**: Modern interface, Coin emoji, Floating button, **English Localization**

### ❌ Optional Enhancements
- **NL Goal Creation**: AI parsing for goal descriptions
- **Multi-language Voice**: Expansion to other languages
- **Predictive Analysis**: Future spending prediction

## Functional Coverage

Based on PRD 3.1:

| Requirement | Status |
|-------------|--------|
| 1. Account System (No login, local storage) | ✅ 100% |
| 2. Manual Entry | ✅ 100% |
| 2. AI Text Entry + 3s Auto-confirm | ✅ 100% |
| 2. AI Voice Entry | ✅ 100% |
| 3. Gemini API Management | ✅ 100% |
| 4. CSV Import/Export | ✅ 100% |
| 5. Reports & AI Assistant | ✅ 100% |
| 6. Savings Goals | ✅ 100% |
| 7. Reminder System | ✅ 100% |

**Overall Completion: 100%** 🎉

## Technical Highlights

- ✅ Modern SwiftUI + SwiftData Architecture
- ✅ Complete Local Data Loop (Import/Export/De-dupe)
- ✅ Smart AI Interaction (Auto-confirm countdown)
- ✅ Secure Keychain Storage
- ✅ UX Optimization (Haptics, Loading States, Error Handling)
- ✅ Full English Localization
- ✅ Build Ready & Runnable

---
config:
  layout: dagre
---
flowchart TB
    Start(["App Launch"]) --> Home["Home (Overview)"]
    Home -- Tab Bar --> Transactions["Transactions List"] & Reports["Reports"] & Goals["Goals"]
    Home -- Toolbar --> Settings["Settings"]
    Home -- Floating Button --> AIEntry{"AI Entry (Voice/Text)"}
    AIEntry --> Gemini[("Gemini API")]
    Gemini --> Confirmation["Confirmation Card"]
    Confirmation -- "Save/Auto-confirm" --> SaveTransaction[("Save to SwiftData")]
    AIEntry -- Manual Toggle --> ManualEntry["Manual Entry Sheet"]
    ManualEntry -- Save --> SaveTransaction
    Transactions -- Tap Card --> EditDelete{"Edit/Delete data"}
    EditDelete -- Edit/Update --> SaveTransaction
    Reports -- SwiftData Query --> ReportVisuals[("Visual Charts (Pie/Line)")]
    Reports -- Generate --> AIInsights["AI Insights"]
    Reports -- Chat --> AIChat["AI Report Assistant"]
    Goals -- View Data --> GoalList[("Goal List (All Goal Info)")]
    Goals -- Add/Manage Funds --> GoalManagement["New Goal/Add Funds"]
    GoalManagement --> SaveTransaction
    Settings -- Export/Import --> CSV["CSV Service"]
    Settings -- Manage --> Categories["Category Management"]
    Settings --> APIConfig["API Configuration"]
    SaveTransaction --> Transactions & Reports & Goals