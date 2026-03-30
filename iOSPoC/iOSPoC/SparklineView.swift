import SwiftUI

/// Sparkline that colors segments green when above the first value (reference)
/// and red when below, with a fading area fill between the value line and reference.
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

            let refY = yPos(reference)

            // MARK: Area fill
            // Build full area path: start at refY, trace the value line, close back at refY
            var areaPath = Path()
            areaPath.move(to: CGPoint(x: xPos(0), y: refY))
            for i in 0..<values.count {
                areaPath.addLine(to: CGPoint(x: xPos(i), y: yPos(values[i])))
            }
            areaPath.addLine(to: CGPoint(x: xPos(values.count - 1), y: refY))
            areaPath.closeSubpath()

            // Green fill — clip to the region above the reference line
            var aboveCtx = context
            aboveCtx.clip(to: Path(CGRect(x: 0, y: 0, width: size.width, height: refY)))
            aboveCtx.fill(areaPath, with: .linearGradient(
                Gradient(colors: [.green.opacity(0.35), .clear]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: refY)
            ))

            // Red fill — clip to the region below the reference line
            var belowCtx = context
            belowCtx.clip(to: Path(CGRect(x: 0, y: refY, width: size.width, height: size.height - refY)))
            belowCtx.fill(areaPath, with: .linearGradient(
                Gradient(colors: [.clear, .red.opacity(0.35)]),
                startPoint: CGPoint(x: 0, y: refY),
                endPoint: CGPoint(x: 0, y: size.height)
            ))

            // MARK: Reference line
            var refPath = Path()
            refPath.move(to: CGPoint(x: 0, y: refY))
            refPath.addLine(to: CGPoint(x: size.width, y: refY))
            context.stroke(refPath, with: .color(.gray.opacity(0.35)),
                           style: StrokeStyle(lineWidth: 0.5, dash: [3, 2]))

            // MARK: Value line — colored segments with exact crossing points
            let lineStyle = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)

            for i in 0..<(values.count - 1) {
                let v1 = values[i], v2 = values[i + 1]
                let p1 = CGPoint(x: xPos(i), y: yPos(v1))
                let p2 = CGPoint(x: xPos(i + 1), y: yPos(v2))

                if (v1 >= reference) == (v2 >= reference) {
                    var path = Path()
                    path.move(to: p1)
                    path.addLine(to: p2)
                    context.stroke(path, with: .color(v1 >= reference ? .green : .red), style: lineStyle)
                } else {
                    let t = (reference - v1) / (v2 - v1)
                    let pCross = CGPoint(x: p1.x + CGFloat(t) * (p2.x - p1.x), y: refY)

                    var path1 = Path()
                    path1.move(to: p1)
                    path1.addLine(to: pCross)
                    context.stroke(path1, with: .color(v1 >= reference ? .green : .red), style: lineStyle)

                    var path2 = Path()
                    path2.move(to: pCross)
                    path2.addLine(to: p2)
                    context.stroke(path2, with: .color(v2 >= reference ? .green : .red), style: lineStyle)
                }
            }
        }
    }
}

#Preview {
    SparklineView(values: [50, 51, 49.5, 52, 48, 50.5, 47, 53])
        .frame(width: 120, height: 44)
        .padding()
        .background(Color.warmSecondaryBackground)
}
