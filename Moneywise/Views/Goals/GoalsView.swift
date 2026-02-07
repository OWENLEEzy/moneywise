import SwiftUI
import SwiftData

struct GoalsView: View {
    @Environment(\.modelContext) private var context
    @Query private var goals: [Goal]
    @State private var showAddGoalSheet = false
    @ObservedObject private var languageManager = LanguageManager.shared
    @Binding var selectedTab: ContentView.Tab
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(goals) { goal in
                    NavigationLink(destination: GoalDetailView(goal: goal)) {
                        GoalRow(goal: goal)
                    }
                }
                .onDelete(perform: deleteGoals)
            }
            .navigationTitle("Goals".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        selectedTab = .home
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back".localized)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddGoalSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddGoalSheet) {
                AddGoalSheet()
            }
            .overlay {
                if goals.isEmpty {
                    ContentUnavailableView(
                        "No goals yet. Set one up!".localized,
                        systemImage: "target",
                        description: Text("Create a savings goal to track your progress.")
                    )
                }
            }
        }
    }
    
    private func deleteGoals(offsets: IndexSet) {
        for index in offsets {
            context.delete(goals[index])
        }
    }
}

struct GoalDetailView: View {
    @Bindable var goal: Goal
    @State private var showAddFundsSheet = false
    @State private var showEditGoalSheet = false
    @ObservedObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Energy Orb Visualization
                EnergyOrbView(progress: goal.progress)
                    .frame(height: 300)
                    .padding(.top, 20)
                
                VStack(spacing: 8) {
                    Text(goal.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Deadline".localized + ": \(goal.deadline.formatted(Date.FormatStyle(date: .long, time: .omitted, locale: LanguageManager.shared.locale)))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Current Progress".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(goal.currentAmount.coinFormatted)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Target Amount".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(goal.targetAmount.coinFormatted)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    Button(action: { showAddFundsSheet = true }) {
                        Text("Add Funds".localized)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 0.2, green: 0.8, blue: 0.6))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Goal Details".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showEditGoalSheet = true }) {
                    Text("Edit".localized)
                }
            }
        }
        .sheet(isPresented: $showAddFundsSheet) {
            AddFundsSheet(goal: goal)
        }
        .sheet(isPresented: $showEditGoalSheet) {
            GoalEditorSheet(goal: goal)
        }
    }
}

struct EnergyOrbView: View {
    let progress: Double
    @State private var isAnimating = false
    @ObservedObject private var languageManager = LanguageManager.shared
    
    // Mint/Green Theme Colors
    private let primaryColor = Color(red: 0.2, green: 0.8, blue: 0.6) // Mint
    private let secondaryColor = Color(red: 0.1, green: 0.6, blue: 0.5) // Darker Green
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let circleSize = min(size.width, size.height)
            
            ZStack {
                // Outer Glow
                Circle()
                    .fill(primaryColor.opacity(0.1))
                    .blur(radius: 20)
                    .scaleEffect(1.2)
                
                // Orb Container
                ZStack {
                    // Circle Border
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [primaryColor.opacity(0.5), secondaryColor.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                    
                    // Wave Fill - Clipped to Circle
                    ZStack {
                        // Background wave layer
                        WaveShape(progress: progress, waveHeight: 10, offset: isAnimating ? 360 : 0)
                            .fill(primaryColor.opacity(0.3))
                            .frame(width: circleSize, height: circleSize)
                        
                        // Foreground wave layer
                        WaveShape(progress: progress, waveHeight: 8, offset: isAnimating ? 360 : 0, phaseShift: 180)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [primaryColor, secondaryColor]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: circleSize, height: circleSize)
                            .opacity(0.8)
                    }
                    .clipShape(Circle())
                }
                .frame(width: circleSize, height: circleSize)
                
                // Text Content
                VStack(spacing: 4) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: primaryColor, radius: 10)
                    
                    Text(progress >= 1.0 ? "COMPLETE".localized : "SAVING".localized)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(progress >= 1.0 ? Color.white : Color.white.opacity(0.7))
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .onAppear {
            withAnimation(Animation.linear(duration: 3).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

struct GoalRow: View {
    let goal: Goal
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.name)
                    .font(.headline)
                Text("Target: \(goal.targetAmount.coinFormatted)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(goal.progress * 100))%")
                    .font(.headline)
                    .foregroundColor(goal.progress >= 1.0 ? .green : Color(red: 0.2, green: 0.8, blue: 0.6))
                
                ProgressView(value: goal.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: goal.progress >= 1.0 ? .green : Color(red: 0.2, green: 0.8, blue: 0.6)))
                    .frame(width: 60)
            }
        }
        .padding(.vertical, 4)
    }
}
