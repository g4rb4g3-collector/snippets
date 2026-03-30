import SwiftUI

/// Sparkline that colors segments green when above the first value (reference)
/// and red when below, with an exact crossing point calculation.
struct SparklineView: View {
    let values: [Double]

    var body: some View {
        Canvas { context, size in
            guard values.count >= 2 else { return }

            let reference = values[0]
            let minVal = values.min()!
            let maxVal = values.max()!
            let range = max(maxVal - minVal, 0.001)

            func xPos(_ index: Int) -> CGFloat {
                CGFloat(index) / CGFloat(values.count - 1) * size.width
            }
            func yPos(_ value: Double) -> CGFloat {
                CGFloat(1.0 - (value - minVal) / range) * size.height
            }

            // Subtle reference line
            let refY = yPos(reference)
            var refPath = Path()
            refPath.move(to: CGPoint(x: 0, y: refY))
            refPath.addLine(to: CGPoint(x: size.width, y: refY))
            context.stroke(refPath, with: .color(.gray.opacity(0.35)),
                           style: StrokeStyle(lineWidth: 0.5, dash: [3, 2]))

            // Colored segments
            let style = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)

            for i in 0..<(values.count - 1) {
                let v1 = values[i], v2 = values[i + 1]
                let p1 = CGPoint(x: xPos(i), y: yPos(v1))
                let p2 = CGPoint(x: xPos(i + 1), y: yPos(v2))

                if (v1 >= reference) == (v2 >= reference) {
                    // No crossing — single colour segment
                    var path = Path()
                    path.move(to: p1)
                    path.addLine(to: p2)
                    context.stroke(path, with: .color(v1 >= reference ? .green : .red), style: style)
                } else {
                    // Crossing — split at the exact intersection with the reference line
                    let t = (reference - v1) / (v2 - v1)
                    let pCross = CGPoint(x: p1.x + CGFloat(t) * (p2.x - p1.x), y: refY)

                    var path1 = Path()
                    path1.move(to: p1)
                    path1.addLine(to: pCross)
                    context.stroke(path1, with: .color(v1 >= reference ? .green : .red), style: style)

                    var path2 = Path()
                    path2.move(to: pCross)
                    path2.addLine(to: p2)
                    context.stroke(path2, with: .color(v2 >= reference ? .green : .red), style: style)
                }
            }
        }
    }
}

#Preview {
    SparklineView(values: [50, 51, 49.5, 52, 48, 50.5, 47, 53])
        .frame(width: 120, height: 44)
        .padding()
}
