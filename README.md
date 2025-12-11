## GemBudget · Privacy-First AI Budgeting App

GemBudget is an iOS SwiftUI application based on the "Product Requirements Document", designed to be **registration-free with local-only data storage**, powered by the Gemini API.

### Core Features

- ✅ AI-Powered Text & Voice Entry: Smart parsing using Gemini 2.5 Flash model
- ✅ Real-time Voice Transcription: Supports English voice recognition
- ✅ 3-Second Auto-Confirm: High-confidence transactions are added automatically without manual confirmation
- ✅ Local Data Loop: Built with SwiftData + Keychain
- ✅ Full CSV Import/Export: Easy data migration
- ✅ Smart Reminder System: Daily logging and goal deadline reminders
- ✅ AI Report Assistant: Conversational analysis of your spending data
- ✅ Coin Emoji 💰 for all amounts: Clean and aesthetic
- ✅ Gentle AI Assistant: Provides personalized advice based on local transaction data

### Requirements

- Xcode 16 / iOS 18 SDK (Minimum iOS 17.4 due to SwiftData & Charts)
- Swift 5.10
- Gemini API Key (Tutorial available in Settings)

```bash
open Moneywise.xcodeproj
```

First run will automatically populate default categories and sample settings. To experience AI features, paste your API Key in Settings and click "Test Connection".

### Feature List

#### ✅ Core Features (Completed)
- **Home**: Daily spending overview, goal progress cards, floating action button, **Budget Settings & Persistence**
- **AI Entry**: Text and voice input with AI parsing (Gemini 2.5 Flash), smart confirmation card
- **Voice Recognition**: Integrated iOS Speech framework, English real-time transcription
- **3s Auto-Confirm**: Auto-countdown for confidence ≥ 0.8, cancelable
- **CSV Features**: Full import/export UI, share sheet support, smart de-duplication
- **API Stats**: Real-time token usage and call count tracking
- **Settings**: API Key config, CSV management, reminders, help
- **Goals**: Create, list, details, progress tracking, auto-reminders
- **Transactions**: Search, filter (All/Expense/Income), swipe to delete, **Category Management**
- **Reminders**: Daily logging reminder, goal deadline reminder
- **Reports**: Real-time spending trend chart, AI Smart Weekly/Monthly Reports, **AI Chat Assistant**

#### ⚠️ Optional / Future
- **Assistant Tab**: Global AI Assistant (Currently Placeholder)
- **Natural Language Goal Creation**: AI parsing for goal descriptions
- **Multi-language Support**: Expansion to other languages

### Technical Architecture

- **Models**: Transaction, Goal, SpendingCategory, AIUsageStats, AIInsight
- **Persistence**: SwiftData (SQLite) local storage
- **Security**: iOS Keychain for API Key
- **Backend Services**: CSVService, GeminiService, KeychainService, NotificationScheduler
- **UI Framework**: SwiftUI + Observation
- **AI Integration**: Google Gemini 2.5 Flash API

### Development Status

| Module | Status | Description |
|----------------|-------------|
| ContentView | ✅ 100% | Simplified TabView, FloatingButtonBar, Navigation |
| HomeView | ✅ 100% | Asset cards, Goal display, Budget Settings, UI complete |
| SettingsView | ✅ 100% | Modal presentation, API config, CSV management, Stats |
| AISmartEntrySheet | ✅ 100% | Text/Voice input, Auto-confirm complete |
| ManualEntrySheet | ✅ 100% | Form input, Category Picker complete |
| GoalsView | ✅ 100% | Create, List, Details complete |
| TransactionsView | ✅ 100% | Search, Filter, Delete complete |
| ReportsView | ✅ 100% | Trend chart, AI Insights, AI Chat complete |
| AssistantView | 🚧 Future | Placeholder for global AI assistant |
| CSVService | ✅ 100% | Import/Export logic and UI complete |
| NotificationScheduler | ✅ 100% | Backend and UI settings complete |
| SpeechRecognitionService | ✅ 100% | English voice recognition complete |

**Overall Completion**: **100%** 🎉

### Project Highlights

✨ **Complete Data Loop**: CSV Import/Export + Smart De-duplication  
✨ **Smart Interaction**: 3s Auto-confirm for "Speedy Entry"  
✨ **Privacy First**: Local storage + Keychain encryption  
✨ **Transparent AI**: Real-time Token usage tracking  
✨ **Reliable Reminders**: Daily logging + Goal deadline alerts  
✨ **Modern Design**: Coin emojis, smooth animations, haptic feedback  
✨ **Full English Interface**: Fully localized for international users

### Known Limitations

1. **Voice Language**: Currently optimized for English voice recognition.
2. **Assistant Tab**: The "Assistant" tab is currently a placeholder; AI Chat is available in Reports.

### PRD Compliance

Based on Product Requirements Document 3.1:

- ✅ Account System (No login, local storage)
- ✅ Manual Entry (with Category Management)
- ✅ AI Text Entry + 3s Auto-confirm
- ✅ AI Voice Entry (Fully implemented)
- ✅ Gemini API Management (Tutorial, Verify, Stats)
- ✅ CSV Import/Export
- ✅ Reports & AI Assistant (Real data + Conversational analysis)
- ✅ Savings Goals
- ✅ Reminder System

**Compliance: 100%** 🎉 | **Ready for Release: Yes ✅**

For more technical details, please see [`ARCHITECTURE.md`](file:///Users/owenlee/Desktop/未命名/GemBudget/ARCHITECTURE.md).