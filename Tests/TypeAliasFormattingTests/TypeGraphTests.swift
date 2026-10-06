import Foundation
import Testing
@testable import TypeAliasFormatting

@Suite struct TypeGraphTests {
    @Test func sharesTypeStructureWithText() throws {
        let result = try TypeAliasFormatter().convert("typealias Body = Pair<Box<A>, (Modifier in _123ABC)<B>>")
        #expect(!result.text.contains("typealias"))
        #expect(result.graph == TypeGraphNode(label: "Pair", children: [
            TypeGraphNode(label: "Box", children: [TypeGraphNode(label: "A")]),
            TypeGraphNode(label: "(Modifier in _123ABC)", children: [TypeGraphNode(label: "B")]),
        ]))
        #expect(try TypeAliasFormatter().convert(" Box < A > ").graph.label == "Box")
    }

    @Test func keepsFunctionAttributesAndTupleArguments() throws {
        let result = try TypeAliasFormatter().convert("@convention(c) (Box<A>, Int) -> Void")
        #expect(result.text.hasPrefix("@convention(c) ("))
        #expect(result.graph.label == "@convention(c) (…) -> Void")
        #expect(result.graph.children.map(\.label) == ["Box", "Int"])
    }

    @Test func laysOutEachNodeAndEdgeOnce() throws {
        let root = try TypeAliasFormatter().convert("Pair<Box<A>, Box<B>>").graph
        let layout = GraphLayout(root: root)
        #expect(layout.nodes.count == root.nodeCount)
        #expect(layout.edges.count == root.nodeCount - 1)
        #expect(Set(layout.nodes.map(\.id)).count == root.nodeCount)
        for node in layout.nodes {
            #expect(node.x >= 0 && node.y >= 0)
            #expect(node.x + GraphLayout.nodeWidth <= layout.width)
            #expect(node.y + GraphLayout.nodeHeight <= layout.height)
        }
        for edge in layout.edges {
            #expect(edge.startX < edge.endX)
        }
    }

    @Test func collapseHidesOnlyDescendants() throws {
        let root = try TypeAliasFormatter().convert("Pair<Box<A>, Box<B>>").graph
        let layout = GraphLayout(root: root, collapsed: ["root.0"])
        #expect(Set(layout.nodes.map(\.id)) == ["root", "root.0", "root.1", "root.1.0"])
        #expect(layout.edges.count == 3)
        #expect(GraphLayout(root: root, collapsed: ["root"]).nodes.count == 1)
    }

    @Test func svgEscapesTypeLabels() throws {
        let root = TypeGraphNode(label: "Box<T> & P", children: [TypeGraphNode(label: "A")])
        let svg = GraphLayout(root: root).svg
        #expect(svg.contains("Box&lt;T&gt; &amp; P"))
        #expect(!svg.contains("typealias"))
        #expect(XMLParser(data: Data(svg.utf8)).parse())
    }
}
