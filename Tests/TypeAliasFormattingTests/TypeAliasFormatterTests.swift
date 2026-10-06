import Foundation
import Testing
@testable import TypeAliasFormatting

@Suite struct TypeAliasFormatterTests {
    private let formatter = TypeAliasFormatter()

    @Test func matchesDefaultLabelStyle() throws {
        let markdown = try fixture("DefaultLabelStyle", extension: "md")
        let expected = markdown.components(separatedBy: "\n").dropFirst().dropLast(2)
            .joined(separator: "\n").replacingOccurrences(of: "typealias Body = ", with: "")
        let input = try fixture("DefaultLabelStyle", extension: "txt")
        let output = try formatter.format(input)
        #expect(output == expected)
        #expect(try formatter.format(output) == output)
        #expect(try formatter.format(markdown) == output)
        let graph = try formatter.convert(input).graph
        #expect(graph.label == "ModifiedContent")
        #expect(graph.nodeCount == 97)
    }

    @Test func expandsMultipleArguments() throws {
        #expect(try formatter.format("typealias Body = Pair<A, Box<B>>") == """
        Pair<
            A,
            Box<B>
        >
        """)
    }

    @Test func matchesResolvedLabelStyle() throws {
        let input = try fixture("ResolvedLabelStyle", extension: "txt")
        let expected = try fixture("ResolvedLabelStyle.formatted", extension: "txt")
            .trimmingCharacters(in: .newlines)
        let result = try formatter.convert(input)
        #expect(result.text == expected)
        #expect(try formatter.format(result.text) == result.text)
        #expect(result.graph.label == "ModifiedContent")
        #expect(result.graph.nodeCount == 27)
        let titleWriter = result.graph.children[0].children[1]
        #expect(titleWriter.label == "(StaticSourceWriter in _D9F7AF928092578A4B8FA861B49E2161)")
        #expect(titleWriter.children.map(\.label) == ["LabelStyleConfiguration.Title", "A"])
    }

    @Test func usesTabsForNestedArguments() throws {
        let input = "typealias Body = Outer<Pair<A, B>>"
        let expected = "Outer<\n\tPair<\n\t\tA,\n\t\tB\n\t>\n>"
        let result = try formatter.convert(input, indentation: .tab)
        #expect(result.text == expected)
        #expect(try formatter.format(result.text, indentation: .tab) == expected)
        #expect(result.graph == (try formatter.convert(input)).graph)
        #expect(try formatter.format("Box<Value>", indentation: .tab, expandSingleArguments: true)
            == "Box<\n\tValue\n>")
    }

    @Test func expandsSingleArgumentWithMultilineChild() throws {
        #expect(try formatter.format("Outer<Pair<A, B>>") == """
        Outer<
            Pair<
                A,
                B
            >
        >
        """)
    }

    @Test func preservesPrivateNamesAndEscapedIdentifiers() throws {
        #expect(try formatter.format("Pair<(Modifier in _123ABC)<Style>, `Type`>") == """
        Pair<
            (Modifier in _123ABC)<Style>,
            `Type`
        >
        """)
    }

    @Test func preservesFunctionArrowsTuplesAndCollections() throws {
        #expect(try formatter.format("typealias F = Pair<@Sendable (Int, String) async throws -> [String: Int], ()->Void>") == """
        Pair<
            @Sendable (Int, String) async throws -> [String: Int],
            ()->Void
        >
        """)
    }

    @Test func preservesSuffixes() throws {
        #expect(try formatter.format("Pair<A, B>.Type?") == """
        Pair<
            A,
            B
        >.Type?
        """)
    }

    @Test func supportsIndentationAndFullExpansion() throws {
        #expect(try formatter.format("Box<Value>", indentation: .twoSpaces, expandSingleArguments: true) == """
        Box<
          Value
        >
        """)
    }

    @Test func normalizesWhitespace() throws {
        #expect(try formatter.format("  typealias  Body  =  Pair< \n A ,  Box< B > > \n") == """
        Pair<
            A,
            Box<B>
        >
        """)
    }

    @Test func acceptsSimpleTypes() throws {
        #expect(try formatter.format("Swift.String") == "Swift.String")
        #expect(try formatter.format("() -> Void") == "() -> Void")
        #expect(try formatter.format("any P & Q") == "any P & Q")
    }

    @Test(arguments: [
        "typealias Body = Box<Value>",
        "public typealias CustomName = Box<Value>",
        "typealias Generic<T> = Box<Value>",
        "  typealias Body\n = \n Box<Value>  ",
    ])
    func stripsDeclarationBeforeFormatting(_ source: String) throws {
        #expect(try formatter.format(source) == "Box<Value>")
    }

    @Test(arguments: [
        "", "   ", "Pair<A, B", "Pair<A, B]", "A>",
        "Pair<, B>", "Pair<A,>", "Box<>", "[]", "A, B",
        "typealias Body =", "typealias Body", "`Unclosed",
        "Box<A // Comment\n>", "Box</* Comment */ A>",
        "```swift\nBox<A>", "```json\nBox<A>\n```",
        "typealias A = Int\ntypealias B = String",
    ])
    func rejectsInvalidInput(_ source: String) {
        #expect(throws: (any Error).self) {
            try formatter.format(source)
        }
    }

    @Test func rejectsExcessiveNestingAndInputSize() {
        let nested = String(repeating: "Box<", count: 200) + "A" + String(repeating: ">", count: 200)
        #expect(throws: (any Error).self) { try formatter.format(nested) }
        #expect(throws: (any Error).self) { try formatter.format(String(repeating: "A", count: 200_001)) }
    }

    private func fixture(_ name: String, extension ext: String) throws -> String {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: BundleToken.self)
        #endif
        let url = try #require(bundle.url(forResource: name, withExtension: ext, subdirectory: "Fixtures")
            ?? bundle.url(forResource: name, withExtension: ext))
        return try String(contentsOf: url, encoding: .utf8)
    }
}

private final class BundleToken: NSObject {}
