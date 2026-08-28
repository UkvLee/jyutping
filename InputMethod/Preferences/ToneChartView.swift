import SwiftUI

struct ToneChartView: View {
        var body: some View {
                GeometryReader { geometry in
                        let height = geometry.size.height
                        let width = geometry.size.width

                        let widthUnit: CGFloat = width / 13.0
                        let heightUnit: CGFloat = height / 5.0

                        // Calculate y position for level k
                        let yOf = { k in (CGFloat(6 - k) - 0.5) * heightUnit }

                        ZStack {
                                Text(verbatim: "高")
                                        .position(x: 0, y: -4)
                                ForEach(1..<6, id: \.self) { levelValue in
                                        Text(verbatim: "\(levelValue)")
                                                .monospacedDigit()
                                                .position(x: 0, y: yOf(levelValue))
                                }
                                Text(verbatim: "低")
                                        .position(x: 0, y: height + 4)
                                ForEach(1..<6, id: \.self) { k in
                                        Path { path in
                                                path.move(to: CGPoint(x: 18, y: yOf(k)))
                                                path.addLine(to: CGPoint(x: width, y: yOf(k)))
                                        }
                                        .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0, 6]))
                                }

                                toneLine(from: CGPoint(x: widthUnit, y: yOf(5)), to: CGPoint(x: widthUnit * 3, y: yOf(5)), color: .red)

                                toneLine(from: CGPoint(x: widthUnit * 3, y: yOf(3)), to: CGPoint(x: widthUnit * 4.5, y: yOf(5)), color: .teal)

                                toneLine(from: CGPoint(x: widthUnit * 4.5, y: yOf(3)), to: CGPoint(x: widthUnit * 6.5, y: yOf(3)), color: .purple)

                                toneLine(from: CGPoint(x: widthUnit * 6.5, y: yOf(2)), to: CGPoint(x: widthUnit * 8.5, y: yOf(1)), color: .orange)

                                toneLine(from: CGPoint(x: widthUnit * 9, y: yOf(1)), to: CGPoint(x: widthUnit * 10.5, y: yOf(3)), color: .green)

                                toneLine(from: CGPoint(x: widthUnit * 10.5, y: yOf(2)), to: CGPoint(x: widthUnit * 12.5, y: yOf(2)), color: .blue)

                                Text(verbatim: "1 陰平")
                                        .position(x: widthUnit * 2, y: yOf(5) - 14)
                                Text(verbatim: "2 陰上")
                                        .position(x: widthUnit * 3.5 - 12, y: yOf(4) - 14)
                                Text(verbatim: "3 陰去")
                                        .position(x: widthUnit * 5.5, y: yOf(3) - 16)
                                Text(verbatim: "4 陽平")
                                        .position(x: widthUnit * 7 - 12, y: yOf(1) - 12)
                                Text(verbatim: "5 陽上")
                                        .position(x: widthUnit * 9.5 - 12, y: yOf(2) - 16)
                                Text(verbatim: "6 陽去")
                                        .position(x: widthUnit * 11.5, y: yOf(2) - 16)
                        }
                }
        }
}

private func toneLine(from start: CGPoint, to end: CGPoint, color: Color) -> some View {
        let angle = atan2(Double(end.y - start.y), Double(end.x - start.x))
        let arrowLength: CGFloat = 12
        let arrowHalfWidth: CGFloat = 6
        let lineEnd = CGPoint(x: end.x - arrowHalfWidth * CGFloat(cos(angle)), y: end.y - arrowHalfWidth * CGFloat(sin(angle)))
        let tip = CGPoint(x: lineEnd.x + arrowLength * CGFloat(cos(angle)), y: lineEnd.y + arrowLength * CGFloat(sin(angle)))
        let firstCorner = CGPoint(x: lineEnd.x + arrowHalfWidth * CGFloat(sin(angle)), y: lineEnd.y - arrowHalfWidth * CGFloat(cos(angle)))
        let secondCorner = CGPoint(x: lineEnd.x - arrowHalfWidth * CGFloat(sin(angle)), y: lineEnd.y + arrowHalfWidth * CGFloat(cos(angle)))
        return ZStack {
                Path { path in
                        path.move(to: start)
                        path.addLine(to: lineEnd)
                }
                .stroke(color, lineWidth: 4)
                Path { path in
                        path.move(to: tip)
                        path.addLine(to: firstCorner)
                        path.addLine(to: secondCorner)
                        path.closeSubpath()
                }
                .fill(color)
        }
}
