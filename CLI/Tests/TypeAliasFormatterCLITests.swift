import Foundation
import Testing
@testable import TypeAliasFormatterCLI

@Suite struct TypeAliasFormatterCLITests {
    @Test func formatsAFileAndRemovesTheDeclaration() throws {
        try withFiles(source: "typealias Body = Pair<A, Box<B>>") { input, output in
            var command = try TypeAliasFormatterCLI.parse([input.path, "-o", output.path])
            try command.run()
            #expect(try String(contentsOf: output, encoding: .utf8) == "Pair<\n    A,\n    Box<B>\n>\n")
        }
    }

    @Test(arguments: [("2", "  "), ("4", "    "), ("8", "        "), ("tab", "\t")])
    func appliesIndentationAndExpansion(option: String, unit: String) throws {
        try withFiles(source: "Box<Value>") { input, output in
            var command = try TypeAliasFormatterCLI.parse([
                input.path, "--output", output.path, "--indent", option, "--expand-generics",
            ])
            try command.run()
            #expect(try String(contentsOf: output, encoding: .utf8) == "Box<\n\(unit)Value\n>\n")
        }
    }

    @Test func exportsACompleteSVGGraph() throws {
        try withFiles(source: "Pair<Box<A>, Box<B>>") { input, output in
            var command = try TypeAliasFormatterCLI.parse([input.path, "-o", output.path, "--format", "graph"])
            try command.run()
            let data = try Data(contentsOf: output)
            let svg = try #require(String(data: data, encoding: .utf8))
            #expect(XMLParser(data: data).parse())
            #expect(svg.contains("<title>A</title>") && svg.contains("<title>B</title>"))
            #expect(!svg.contains("typealias"))
        }
    }

    @Test func leavesOutputUnchangedWhenFormattingFails() throws {
        try withFiles(source: "Pair<A,") { input, output in
            try "Keep this file".write(to: output, atomically: true, encoding: .utf8)
            var command = try TypeAliasFormatterCLI.parse([input.path, "-o", output.path])
            #expect(throws: (any Error).self) { try command.run() }
            #expect(try String(contentsOf: output, encoding: .utf8) == "Keep this file")
        }
    }

    @Test func rejectsInvalidUTF8WithoutCreatingOutput() throws {
        try withFiles(source: "") { input, output in
            try Data([0xFF]).write(to: input)
            var command = try TypeAliasFormatterCLI.parse([input.path, "-o", output.path])
            #expect(throws: (any Error).self) { try command.run() }
            #expect(!FileManager.default.fileExists(atPath: output.path))
        }
    }

    @Test(arguments: [200_000, 200_001])
    func enforcesInputSizeLimit(size: Int) throws {
        try withFiles(source: String(repeating: "A", count: size)) { input, output in
            var command = try TypeAliasFormatterCLI.parse([input.path, "-o", output.path])
            if size == 200_000 {
                try command.run()
                #expect(try Data(contentsOf: output).count == size + 1)
            } else {
                #expect(throws: (any Error).self) { try command.run() }
                #expect(!FileManager.default.fileExists(atPath: output.path))
            }
        }
    }

    @Test func supportsTheSameInputAndOutputFile() throws {
        try withFiles(source: "Pair<A, B>") { input, _ in
            var command = try TypeAliasFormatterCLI.parse([input.path, "-o", input.path])
            try command.run()
            #expect(try String(contentsOf: input, encoding: .utf8) == "Pair<\n    A,\n    B\n>\n")
        }
    }

    private func withFiles(source: String, body: (URL, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("input.txt")
        let output = directory.appendingPathComponent("output.txt")
        try source.write(to: input, atomically: true, encoding: .utf8)
        try body(input, output)
    }
}
