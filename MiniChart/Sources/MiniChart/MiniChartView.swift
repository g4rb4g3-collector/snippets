import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A lightweight line chart view that renders an array of Double values as a continuous line.
/// Supports long-press gesture to show a vertical indicator line with the selected value.
public struct MiniChartView: View {
    public var data: [Double]
    public var lineColor: Color
    public var lineWidth: CGFloat
    public var indicatorColor: Color
    public var onSelectionChanged: ((Int, Double)?) -> Void

    @State private var selectedIndex: Int?
    @State private var isTouching = false
    #if canImport(UIKit)
    private let haptic = UISelectionFeedbackGenerator()
    #endif

    public init(
        data: [Double],
        lineColor: Color = .blue,
        lineWidth: CGFloat = 2,
        indicatorColor: Color = .gray,
        onSelectionChanged: @escaping ((Int, Double)?) -> Void = { _ in }
    ) {
        self.data = data
        self.lineColor = lineColor
        self.lineWidth = lineWidth
        self.indicatorColor = indicatorColor
        self.onSelectionChanged = onSelectionChanged
    }

    public var body: some View {
        GeometryReader { geometry in
            if data.count >= 2, let minVal = data.min(), let maxVal = data.max() {
                let range = maxVal - minVal
                let effectiveRange = range == 0 ? 1.0 : range
                VStack(alignment: .leading, spacing: 2) {
                    // Value label in top-left corner
                    if isTouching, let idx = selectedIndex {
                        Text("selected value: \(formatValue(data[idx]))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("last value: \(formatValue(data[data.count - 1]))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    GeometryReader { chartGeometry in
                        let chartHeight = chartGeometry.size.height
                        let chartWidth = chartGeometry.size.width
                        let chartStepX = chartWidth / CGFloat(data.count - 1)

                        ZStack(alignment: .topLeading) {
                            // Line chart
                            Path { path in
                                for (index, value) in data.enumerated() {
                                    let x = chartStepX * CGFloat(index)
                                    let normalizedY = (value - minVal) / effectiveRange
                                    let y = chartHeight * (1 - CGFloat(normalizedY))

                                    if index == 0 {
                                        path.move(to: CGPoint(x: x, y: y))
                                    } else {
                                        path.addLine(to: CGPoint(x: x, y: y))
                                    }
                                }
                            }
                            .stroke(lineColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

                            // Vertical indicator + dot
                            if isTouching, let idx = selectedIndex {
                                let x = chartStepX * CGFloat(idx)
                                let value = data[idx]
                                let normalizedY = (value - minVal) / effectiveRange
                                let y = chartHeight * (1 - CGFloat(normalizedY))

                                Path { path in
                                    path.move(to: CGPoint(x: x, y: 0))
                                    path.addLine(to: CGPoint(x: x, y: chartHeight))
                                }
                                .stroke(indicatorColor, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

                                Circle()
                                    .fill(lineColor)
                                    .frame(width: 8, height: 8)
                                    .position(x: x, y: y)
                            }
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag in
                                    if !isTouching {
                                        isTouching = true
                                        #if canImport(UIKit)
                                        haptic.prepare()
                                        #endif
                                    }
                                    let idx = indexForX(drag.location.x, stepX: chartStepX)
                                    if idx != selectedIndex {
                                        selectedIndex = idx
                                        #if canImport(UIKit)
                                        haptic.selectionChanged()
                                        #endif
                                        if let idx = selectedIndex {
                                            onSelectionChanged((idx, data[idx]))
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    isTouching = false
                                    selectedIndex = nil
                                    onSelectionChanged(nil)
                                }
                        )
                    }
                }
            }
        }
    }

    private func indexForX(_ x: CGFloat, stepX: CGFloat) -> Int {
        let idx = Int(round(x / stepX))
        return max(0, min(data.count - 1, idx))
    }

    private func formatValue(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }
}

#Preview {
    MiniChartView(data: [3, 7, 2, 9, 4, 6, 8, 1, 5])
        .frame(width: 200, height: 80)
        .padding()
}
