import SwiftUI
import TypeAliasFormatterCore

struct TypeGraphView: View {
    let root: TypeGraphNode
    let layout: GraphLayout
    @Binding var collapsed: Set<String>
    let selectedID: String?
    let onSelect: (String?) -> Void
    @State private var zoom = 0.8

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button("Expand all") { collapsed = [] }
                        .disabled(collapsed.isEmpty)
                    Button("Collapse all") {
                        collapsed = Set(GraphLayout(root: root).nodes.filter { $0.childCount > 0 }.map(\.id))
                        if selectedID != nil { onSelect("root") }
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
                GeometryReader { viewport in
                    ScrollViewReader { proxy in
                        ScrollView([.horizontal, .vertical]) {
                            diagram
                                .scaleEffect(zoom, anchor: .topLeading)
                                .frame(width: layout.width * zoom, height: layout.height * zoom, alignment: .topLeading)
                                .id("diagram")
                        }
                        .task(id: selectedID) {
                            await Task.yield()
                            guard let node = layout.nodes.first(where: { $0.id == selectedID }) else { return }
                            // Use the scaled canvas bounds; positioned cards have unscaled scroll targets.
                            let anchor = UnitPoint(
                                x: scrollAnchor((node.x + GraphLayout.nodeWidth / 2) * zoom,
                                                content: layout.width * zoom, viewport: viewport.size.width),
                                y: scrollAnchor((node.y + GraphLayout.nodeHeight / 2) * zoom,
                                                content: layout.height * zoom, viewport: viewport.size.height)
                            )
                            proxy.scrollTo("diagram", anchor: anchor)
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))
                Divider()
                HStack {
                    Text("Select a node to highlight its source. Use the arrow to fold arguments.")
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

    private func scrollAnchor(_ center: CGFloat, content: CGFloat, viewport: CGFloat) -> CGFloat {
        guard content > viewport else { return 0 }
        return min(1, max(0, (center - viewport / 2) / (content - viewport)))
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
                HStack(spacing: 0) {
                    Button { onSelect(node.id) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(node.displayLines.enumerated()), id: \.offset) { _, line in
                                Text(line).lineLimit(1)
                            }
                        }
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .padding(.leading, 14)
                        .contentShape(Rectangle())
                    }
                    .help(node.label)
                    .accessibilityLabel(node.label)
                    .accessibilityValue(selectedID == node.id ? "Selected" : "Not selected")
                    .accessibilityIdentifier("graph.\(node.id)")
                    if node.childCount > 0 {
                        Button {
                            if collapsed.contains(node.id) { collapsed.remove(node.id) }
                            else {
                                collapsed.insert(node.id)
                                if selectedID?.hasPrefix(node.id + ".") == true { onSelect(node.id) }
                            }
                        } label: {
                            VStack(spacing: 5) {
                                Image(systemName: collapsed.contains(node.id) ? "chevron.right" : "chevron.down")
                                Text("\(node.childCount)")
                            }
                            .font(.caption2)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 36, height: GraphLayout.nodeHeight)
                            .contentShape(Rectangle())
                        }
                        .accessibilityLabel("\(collapsed.contains(node.id) ? "Expand" : "Collapse") \(node.label)")
                        .accessibilityIdentifier("collapse.\(node.id)")
                    }
                }
                .buttonStyle(.plain)
                .frame(width: GraphLayout.nodeWidth, height: GraphLayout.nodeHeight)
                .background(selectedID == node.id ? Color.accentColor.opacity(0.15) : Color(nsColor: .textBackgroundColor),
                            in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(selectedID == node.id ? Color.accentColor : .secondary.opacity(0.35),
                                      lineWidth: selectedID == node.id ? 2 : 1)
                }
                .position(x: node.x + GraphLayout.nodeWidth / 2, y: node.y + GraphLayout.nodeHeight / 2)
            }
        }
        .frame(width: layout.width, height: layout.height)
    }
}
