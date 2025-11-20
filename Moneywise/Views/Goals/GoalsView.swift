import SwiftUI
import SwiftData

struct GoalsView: View {
    @Query private var goals: [Goal]
    
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Goal") {
                        // TODO: Implement add goal functionality
                    }
                }
            }
        }
    }
}

struct GoalDetailView: View {
    @Bindable var goal: Goal
    
    var body: some View {
        VStack(spacing: 24) {
            Text(goal.name)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            MountainProgressView(progress: goal.progress)
                .frame(height: 200)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Target amount")
                    Spacer()
                    Text(goal.targetAmount, format: .currency(code: "CNY"))
                }
                HStack {
                    Text("Saved")
                    Spacer()
                    Text(goal.currentAmount, format: .currency(code: "CNY"))
                        .foregroundColor(.green)
                }
                Text("Left to reach goal")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Text("Based on current pace, expected to July 2026, 1 month ahead to schedule!")
                .font(.footnote)
                .foregroundColor(.secondary)
            
            Button("Add Funds") {
                // TODO: Implement add funds functionality
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle(goal.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MountainProgressView: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            Path { path in
                path.move(to: CGPoint(x: width * 0.1, y: height * 0.8))
                path.addLine(to: CGPoint(x: width * 0.3, y: height * 0.3))
                path.addLine(to: CGPoint(x: width * 0.5, y: height * 0.6))
                path.addLine(to: CGPoint(x: width * 0.7, y: height * 0.2))
                path.addLine(to: CGPoint(x: width * 0.9, y: height * 0.8))
                path.closeSubpath()
            }
            .stroke(Color.black, lineWidth: 2)
            
            Path { path in
                path.move(to: CGPoint(x: width * 0.1, y: height * 0.8))
                path.addLine(to: CGPoint(x: width * 0.3, y: height * 0.3))
                path.addLine(to: CGPoint(x: width * 0.5, y: height * 0.6))
                path.addLine(to: CGPoint(x: width * 0.7, y: height * 0.2))
                path.addLine(to: CGPoint(x: width * 0.9, y: height * 0.8))
                path.addLine(to: CGPoint(x: width * 0.9, y: height))
                path.addLine(to: CGPoint(x: width * 0.1, y: height))
                path.closeSubpath()
            }
            .fill(Color.green.opacity(0.3))
            
            Path { path in
                path.move(to: CGPoint(x: width * 0.1, y: height * 0.8))
                path.addLine(to: CGPoint(x: width * 0.3, y: height * 0.3))
                path.addLine(to: CGPoint(x: width * 0.5, y: height * 0.6))
                path.addLine(to: CGPoint(x: width * 0.7, y: height * 0.2))
                path.addLine(to: CGPoint(x: width * 0.9, y: height * 0.8))
                path.addLine(to: CGPoint(x: width * 0.9, y: height * (1 - progress)))
                path.addLine(to: CGPoint(x: width * 0.1, y: height * (1 - progress)))
                path.closeSubpath()
            }
            .fill(Color.green)
        }
    }
}
