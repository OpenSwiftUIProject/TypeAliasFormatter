import Foundation
import Testing
@testable import TypeAliasFormatterCore

@Suite struct TypeMappingTests {
    @Test func mapsRepeatedTypesToSeparateOccurrences() throws {
        let source = "typealias Body = Pair<Box<Value>, Box<Value>>"
        let result = try TypeAliasFormatter().convert(source)
        let first = try #require(result.mappings.first { $0.id == "root.0.0" })
        let second = try #require(result.mappings.first { $0.id == "root.1.0" })
        #expect(slice(source, first.sourceRange) == "Value")
        #expect(slice(source, second.sourceRange) == "Value")
        #expect(first.sourceRange != second.sourceRange)
        #expect(first.formattedRange != second.formattedRange)
        #expect(result.mapping(containing: second.sourceRange, in: .source)?.id == second.id)
        #expect(result.mapping(containing: second.formattedRange, in: .formatted)?.id == second.id)
    }

    @Test func preservesOriginalOffsetsThroughFencesHeadersAndUnicode() throws {
        let source = " \r\n```swift\r\npublic typealias Body = Pair<`😀`, (Modifier in _123ABC)<Cafe\u{301}>>\r\n```\r\n"
        let result = try TypeAliasFormatter().convert(source, indentation: .tab, expandSingleArguments: true)
        let root = try #require(result.mappings.first { $0.id == "root" })
        #expect(slice(source, root.sourceRange) == "Pair<`😀`, (Modifier in _123ABC)<Cafe\u{301}>>")
        for id in ["root.0", "root.1.0"] {
            let mapping = try #require(result.mappings.first { $0.id == id })
            #expect(slice(source, mapping.sourceRange) == slice(result.text, mapping.formattedRange))
        }
        #expect(result.mapping(containing: UTF16Range(2, 2), in: .source) == nil)
    }

    @Test func selectsTheSmallestEnclosingType() throws {
        let source = "Pair<Box<A>, Box<B>>"
        let result = try TypeAliasFormatter().convert(source)
        #expect(result.mapping(containing: UTF16Range(5, 5), in: .source)?.id == "root.0")
        #expect(result.mapping(containing: UTF16Range(9, 10), in: .source)?.id == "root.0.0")
        #expect(result.mapping(containing: UTF16Range(5, 18), in: .source)?.id == "root")
        #expect(result.mapping(containing: UTF16Range(11, 11), in: .source)?.id == "root")
        #expect(result.mapping(containing: UTF16Range(-1, 0), in: .source) == nil)
        #expect(result.mapping(containing: UTF16Range(0, 100), in: .source) == nil)
    }

    @Test func mapsTupleFunctionAndCollectionChildren() throws {
        let source = "@Sendable (Box<A>, [String: Box<B>]) -> Pair<C, D>?"
        let result = try TypeAliasFormatter().convert(source)
        #expect(Set(result.mappings.map(\.id)) == Set(GraphLayout(root: result.graph).nodes.map(\.id)))
        for mapping in result.mappings {
            let original = slice(source, mapping.sourceRange)
            let formatted = slice(result.text, mapping.formattedRange)
            #expect(try TypeAliasFormatter().format(original) == TypeAliasFormatter().format(formatted))
        }
    }

    @Test func preservesIDsAcrossIndentationAndExpansion() throws {
        let source = "Outer<Pair<Box<A>, Box<B>>>"
        let compact = try TypeAliasFormatter().convert(source)
        let expanded = try TypeAliasFormatter().convert(source, indentation: .tab, expandSingleArguments: true)
        #expect(compact.mappings.map(\.id) == expanded.mappings.map(\.id))
        #expect(compact.mappings.map(\.sourceRange) == expanded.mappings.map(\.sourceRange))
        #expect(compact.text != expanded.text)
    }

    @Test func mapsTheMaximumSupportedNesting() throws {
        let source = String(repeating: "Box<", count: 128) + "Leaf" + String(repeating: ">", count: 128)
        let result = try TypeAliasFormatter().convert(source)
        #expect(result.mappings.count == 129)
        let leaf = try #require(result.mappings.last)
        #expect(slice(source, leaf.sourceRange) == "Leaf")
        #expect(slice(result.text, leaf.formattedRange) == "Leaf")
        #expect(throws: (any Error).self) { try TypeAliasFormatter().convert("Box<" + source + ">") }
    }

    @Test(arguments: ["DefaultLabelStyle", "ResolvedLabelStyle"])
    func mapsEveryFixtureNode(_ name: String) throws {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "txt", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: name, withExtension: "txt"))
        let source = try String(contentsOf: url, encoding: .utf8)
        let formatter = TypeAliasFormatter()
        let result = try formatter.convert(source)
        #expect(result.mappings.count == result.graph.nodeCount)
        for mapping in result.mappings {
            #expect(try formatter.format(slice(source, mapping.sourceRange))
                == formatter.format(slice(result.text, mapping.formattedRange)))
        }
    }

    private func slice(_ text: String, _ range: UTF16Range) -> String {
        (text as NSString).substring(with: NSRange(location: range.lowerBound, length: range.upperBound - range.lowerBound))
    }
}
