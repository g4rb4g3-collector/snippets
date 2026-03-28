import SwiftUI

/// A lightweight line chart view that renders an array of Double values as a continuous line.
public struct MiniChartView: View {
    public var data: [Double]
    public var lineColor: Color
    public var lineWidth: CGFloat

    public init(data: [Double], lineColor: Color = .blue, lineWidth: CGFloat = 2) {
        self.data = data
        self.lineColor = lineColor
        self.lineWidth = lineWidth
    }

    public var body: some View {
        GeometryReader { geometry in
            if data.count >= 2, let minVal = data.min(), let maxVal = data.max() {
                let range = maxVal - minVal
                let effectiveRange = range == 0 ? 1.0 : range

                Path { path in
                    let stepX = geometry.size.width / CGFloat(data.count - 1)

                    for (index, value) in data.enumerated() {
                        let x = stepX * CGFloat(index)
                        let normalizedY = (value - minVal) / effectiveRange
                        let y = geometry.size.height * (1 - CGFloat(normalizedY))

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(lineColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

#Preview {
    MiniChartView(data: [3, 7, 2, 9, 4, 6, 8, 1, 5])
        .frame(width: 200, height: 80)
        .padding()
}
