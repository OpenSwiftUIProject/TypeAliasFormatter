import SwiftUI
import TypeAliasFormatterCore

struct TypeGraphView: View {
    let root: TypeGraphNode
    let layout: GraphLayout
    @Binding var collapsed: Set<String>
    @State private var zoom = 0.8

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button("Expand all") { collapsed = [] }
                        .disabled(collapsed.isEmpty)
                    Button("Collapse all") {
                        collapsed = Set(GraphLayout(root: root).nodes.filter { $0.childCount > 0 }.map(\.id))
                        zoom = 0.8
                    }
                    .disabled(collapsed.contains("root"))
                    Spacer(minLength: 4)
                    Button { zoom = max(0.1, zoom - 0.1) } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .help("Zoom out")
                    Text("\(Int((zoom * 100).rounded()))%")
                        .monospacedDigit()
                        .frame(width: 38)
                    Button { zoom = min(1.5, zoom + 0.1) } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .help("Zoom in")
                    Button("Fit") {
                        zoom = min(1, max(0.05, min(
                            geometry.size.width / layout.width,
                            (geometry.size.height - 70) / layout.height
                        )))
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                Divider()
                ScrollView([.horizontal, .vertical]) {
                    diagram
                        .scaleEffect(zoom, anchor: .topLeading)
                        .frame(width: layout.width * zoom, height: layout.height * zoom, alignment: .topLeading)
                }
                .background(Color(nsColor: .controlBackgroundColor))
                Divider()
                HStack {
                    Text("Click a node to expand or collapse its arguments.")
                    Spacer()
                    Text("\(layout.nodes.count) / \(root.nodeCount) nodes")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    private var diagram: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                for edge in layout.edges {
                    var path = Path()
                    let middle = (edge.startX + edge.endX) / 2
                    path.move(to: CGPoint(x: edge.startX, y: edge.startY))
                    path.addCurve(to: CGPoint(x: edge.endX, y: edge.endY),
                                  control1: CGPoint(x: middle, y: edge.startY),
                                  control2: CGPoint(x: middle, y: edge.endY))
                    context.stroke(path, with: .color(.secondary.opacity(0.5)), lineWidth: 1.5)
                }
            }
            .accessibilityHidden(true)
            ForEach(layout.nodes) { node in
                Button {
                    guard node.childCount > 0 else { return }
                    if collapsed.contains(node.id) { collapsed.remove(node.id) }
                    else { collapsed.insert(node.id) }
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(node.displayLines.enumerated()), id: \.offset) { _, line in
                                Text(line).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                            }
                        }
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                        if node.childCount > 0 {
                            VStack(spacing: 5) {
                                Image(systemName: collapsed.contains(node.id) ? "chevron.right" : "chevron.down")
                                Text("\(node.childCount)")
                            }
                            .font(.caption2)
                            .foregroundStyle(Color.accentColor)
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(width: GraphLayout.nodeWidth, height: GraphLayout.nodeHeight)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(collapsed.contains(node.id) ? Color.accentColor : .secondary.opacity(0.35))
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .help(node.label)
                .accessibilityLabel(node.label)
                .accessibilityValue(node.childCount == 0 ? "Leaf" : collapsed.contains(node.id) ? "Collapsed" : "Expanded")
                .accessibilityIdentifier("graph.\(node.id)")
                .position(x: node.x + GraphLayout.nodeWidth / 2, y: node.y + GraphLayout.nodeHeight / 2)
            }
        }
        .frame(width: layout.width, height: layout.height)
    }
}
