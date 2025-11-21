import SwiftUI
import SwiftData

struct GoalsView: View {
    @Binding var selectedTab: ContentView.Tab
    @Query private var goals: [Goal]
    @State private var showAddGoal = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(goals) { goal in
                    NavigationLink {
                        GoalDetailView(goal: goal)
                    } label: {
                        HStack {
                            Text(goal.name)
                            Spacer()
                            Text("\(Int(goal.progress * 100))%")
                        }
                    }
                }
            }
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { selectedTab = .home }) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddGoal = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddGoal) {
                AddGoalSheet()
            }
        }
    }
}

struct GoalDetailView: View {
    @Bindable var goal: Goal
    @State private var showAddFunds = false
    
    private var dailySavingsNeeded: Decimal {
        let remaining = goal.targetAmount - goal.currentAmount
        guard remaining > 0 else { return 0 }
        
        let calendar = Calendar.current
        let now = Date()
        let daysUntilDeadline = calendar.dateComponents([.day], from: now, to: goal.deadline).day ?? 0
        
        guard daysUntilDeadline > 0 else { return remaining }
        
        return remaining / Decimal(daysUntilDeadline)
    }
    
    private var savingsMessage: String {
        let remaining = goal.targetAmount - goal.currentAmount
        
        if remaining <= 0 {
            return "🎉 恭喜！您已达成目标！"
        }
        
        let calendar = Calendar.current
        let now = Date()
        let daysUntilDeadline = calendar.dateComponents([.day], from: now, to: goal.deadline).day ?? 0
        
        if daysUntilDeadline <= 0 {
            return "⚠️ 目标截止日期已过"
        }
        
        return "每天需要储蓄 💰\(dailySavingsNeeded.coinFormatted) 即可达成目标"
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Text(goal.name)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            PiggyBankProgressView(progress: goal.progress)
                .frame(height: 200)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Target amount")
                    Spacer()
                    Text(goal.targetAmount.coinFormatted)
                }
                HStack {
                    Text("Saved")
                    Spacer()
                    Text(goal.currentAmount.coinFormatted)
                        .foregroundColor(.green)
                }
                HStack {
                    Text("Deadline")
                    Spacer()
                    Text(goal.deadline.formatted(date: .abbreviated, time: .omitted))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Text(savingsMessage)
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Add Funds") {
                showAddFunds = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle(goal.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddFunds) {
            AddFundsSheet(goal: goal)
        }
    }
}

struct PiggyBankProgressView: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack {
                // Background (Empty Piggy)
                PiggyBankShape()
                    .fill(Color.pink.opacity(0.1))
                
                // Outline
                PiggyBankShape()
                    .stroke(Color.pink.opacity(0.6), lineWidth: 3)
                
                // Liquid Fill
                PiggyBankShape()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.pink,
                                Color.pink.opacity(0.7)
                            ]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .mask(
                        GeometryReader { geo in
                            VStack {
                                Spacer()
                                Rectangle()
                                    .frame(height: geo.size.height * CGFloat(progress))
                            }
                        }
                    )
                
                // Details (Eye & Slot) - Overlay on top
                PiggyBankDetailsShape()
                    .stroke(Color.pink.opacity(0.8), lineWidth: 2)
                
                // Percentage text
                Text("\(Int(progress * 100))%")
                    .font(.system(size: min(width, height) * 0.2, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .pink, radius: 2)
            }
        }
    }
}

struct PiggyBankShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let w = rect.width
        let h = rect.height
        
        // Start at top of snout
        path.move(to: CGPoint(x: w * 0.85, y: h * 0.45))
        
        // Forehead to Ear
        path.addQuadCurve(
            to: CGPoint(x: w * 0.7, y: h * 0.25),
            control: CGPoint(x: w * 0.8, y: h * 0.3)
        )
        
        // Ear
        path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.1))
        path.addLine(to: CGPoint(x: w * 0.6, y: h * 0.25))
        
        // Back
        path.addQuadCurve(
            to: CGPoint(x: w * 0.15, y: h * 0.4),
            control: CGPoint(x: w * 0.4, y: h * 0.15)
        )
        
        // Tail
        path.addQuadCurve(
            to: CGPoint(x: w * 0.05, y: h * 0.35),
            control: CGPoint(x: w * 0.1, y: h * 0.3)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.12, y: h * 0.5),
            control: CGPoint(x: w * 0.02, y: h * 0.45)
        )
        
        // Rump
        path.addQuadCurve(
            to: CGPoint(x: w * 0.15, y: h * 0.7),
            control: CGPoint(x: w * 0.08, y: h * 0.6)
        )
        
        // Back Leg
        path.addLine(to: CGPoint(x: w * 0.15, y: h * 0.85))
        path.addLine(to: CGPoint(x: w * 0.25, y: h * 0.85))
        path.addLine(to: CGPoint(x: w * 0.25, y: h * 0.75))
        
        // Belly
        path.addQuadCurve(
            to: CGPoint(x: w * 0.6, y: h * 0.75),
            control: CGPoint(x: w * 0.4, y: h * 0.85)
        )
        
        // Front Leg
        path.addLine(to: CGPoint(x: w * 0.6, y: h * 0.85))
        path.addLine(to: CGPoint(x: w * 0.7, y: h * 0.85))
        path.addLine(to: CGPoint(x: w * 0.7, y: h * 0.65))
        
        // Chin
        path.addQuadCurve(
            to: CGPoint(x: w * 0.85, y: h * 0.6),
            control: CGPoint(x: w * 0.8, y: h * 0.7)
        )
        
        // Snout Face
        path.addLine(to: CGPoint(x: w * 0.95, y: h * 0.6))
        path.addLine(to: CGPoint(x: w * 0.95, y: h * 0.45))
        
        path.closeSubpath()
        
        return path
    }
}

struct PiggyBankDetailsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Eye
        let eyeRect = CGRect(x: w * 0.72, y: h * 0.38, width: w * 0.04, height: w * 0.04)
        path.addEllipse(in: eyeRect)
        
        // Coin Slot
        path.move(to: CGPoint(x: w * 0.45, y: h * 0.25))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.55, y: h * 0.25),
            control: CGPoint(x: w * 0.5, y: h * 0.22)
        )
        
        return path
    }
}
