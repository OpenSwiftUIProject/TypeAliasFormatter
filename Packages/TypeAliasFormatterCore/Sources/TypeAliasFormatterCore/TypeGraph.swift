import Foundation

public struct FormattedType: Sendable, Codable {
    public let text: String
    public let graph: TypeGraphNode
    public let mappings: [TypeMapping]
}

public struct TypeGraphNode: Sendable, Equatable, Codable {
    public let label: String
    public let children: [TypeGraphNode]

    public init(label: String, children: [TypeGraphNode] = []) {
        self.label = label
        self.children = children
    }

    public var nodeCount: Int { 1 + children.reduce(0) { $0 + $1.nodeCount } }
}

public struct GraphPlacement: Sendable, Identifiable, Codable {
    public let id: String
    public let label: String
    public let childCount: Int
    public let x: Double
    public let y: Double

    public var displayLines: [String] {
        var remainder = label[...]
        var lines: [String] = []
        while !remainder.isEmpty, lines.count < 3 {
            let end = remainder.index(remainder.startIndex, offsetBy: 27, limitedBy: remainder.endIndex)
                ?? remainder.endIndex
            if lines.count == 2, end < remainder.endIndex {
                lines.append(String(remainder[..<end]) + "…")
                break
            }
            lines.append(String(remainder[..<end]))
            remainder = remainder[end...]
        }
        return lines
    }
}

public struct GraphEdge: Sendable, Codable {
    public let parentID: String
    public let childID: String
    public let startX: Double
    public let startY: Double
    public let endX: Double
    public let endY: Double
}

public struct GraphLayout: Sendable, Codable {
    public static let nodeWidth = 256.0
    public static let nodeHeight = 84.0
    public let nodes: [GraphPlacement]
    public let edges: [GraphEdge]
    public let width: Double
    public let height: Double

    public init(root: TypeGraphNode, collapsed: Set<String> = []) {
        var nodes: [GraphPlacement] = []
        var edges: [GraphEdge] = []
        var cursor = 32.0

        @discardableResult
        func place(_ node: TypeGraphNode, id: String, depth: Int) -> GraphPlacement {
            let children = collapsed.contains(id) ? [] : node.children.enumerated().map { index, child in
                place(child, id: "\(id).\(index)", depth: depth + 1)
            }
            let y: Double
            if let first = children.first, let last = children.last {
                y = (first.y + last.y) / 2
            } else {
                y = cursor
                cursor += Self.nodeHeight + 24
            }
            let placement = GraphPlacement(id: id, label: node.label, childCount: node.children.count,
                                           x: 32 + Double(depth) * (Self.nodeWidth + 64), y: y)
            nodes.append(placement)
            for child in children {
                edges.append(GraphEdge(parentID: id, childID: child.id,
                                       startX: placement.x + Self.nodeWidth,
                                       startY: placement.y + Self.nodeHeight / 2,
                                       endX: child.x, endY: child.y + Self.nodeHeight / 2))
            }
            return placement
        }
        place(root, id: "root", depth: 0)
        self.nodes = nodes
        self.edges = edges
        width = (nodes.map(\.x).max() ?? 32) + Self.nodeWidth + 32
        height = max(cursor + 8, Self.nodeHeight + 64)
    }

    public var svg: String {
        var elements = [
            #"<svg xmlns="http://www.w3.org/2000/svg" width="\#(width)" height="\#(height)" viewBox="0 0 \#(width) \#(height)">"#,
            "<title>Type structure</title>",
            #"<rect width="100%" height="100%" fill="rgb(246,248,251)"/>"#,
        ]
        for edge in edges {
            let middle = (edge.startX + edge.endX) / 2
            elements.append(#"<path d="M \#(edge.startX) \#(edge.startY) C \#(middle) \#(edge.startY), \#(middle) \#(edge.endY), \#(edge.endX) \#(edge.endY)" fill="none" stroke="rgb(160,173,192)" stroke-width="1.5"/>"#)
        }
        for node in nodes {
            elements.append("<g data-node-id=\"\(node.id)\"><title>\(Self.escape(node.label))</title>")
            elements.append(#"<rect x="\#(node.x)" y="\#(node.y)" width="\#(Self.nodeWidth)" height="\#(Self.nodeHeight)" rx="10" fill="white" stroke="rgb(91,134,199)"/>"#)
            let lines = node.displayLines
            let top = node.y + Self.nodeHeight / 2 - Double(lines.count - 1) * 8 + 4
            for (index, line) in lines.enumerated() {
                elements.append(#"<text x="\#(node.x + 14)" y="\#(top + Double(index) * 16)" font-family="Menlo, monospace" font-size="12" fill="rgb(23,42,70)">\#(Self.escape(line))</text>"#)
            }
            elements.append("</g>")
        }
        elements.append("</svg>")
        return elements.joined(separator: "\n") + "\n"
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
