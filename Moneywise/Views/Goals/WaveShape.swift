import SwiftUI

// Custom Wave Shape for proper percentage filling
struct WaveShape: Shape {
    var progress: Double  // 0.0 to 1.0
    var waveHeight: CGFloat
    var offset: Double
    var phaseShift: Double = 0
    
    var animatableData: Double {
        get { offset }
        set { offset = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        // Calculate the water level based on progress
        // At 0% progress: waterLevel = height (bottom)
        // At 100% progress: waterLevel = 0 (top)
        let waterLevel = height * CGFloat(1.0 - progress)
        
        // Start the path from bottom left
        path.move(to: CGPoint(x: 0, y: height))
        
        // Draw line to where wave starts
        path.addLine(to: CGPoint(x: 0, y: waterLevel))
        
        // Draw the wave
        let waveLength: CGFloat = width / 2
        let frequency: CGFloat = 2.0 * .pi / waveLength
        
        for x in stride(from: 0, through: width, by: 1) {
            let relativeX = x / width
            let normalizedOffset = (offset / 360.0)
            let phaseShiftNormalized = (phaseShift / 360.0)
            let sine = sin((relativeX + normalizedOffset + phaseShiftNormalized) * frequency * .pi * 2)
            let y = waterLevel + sine * waveHeight
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        // Close the path
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        
        return path
    }
}
