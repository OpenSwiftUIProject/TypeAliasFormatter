import ArgumentParser
import Darwin
import Foundation
import TypeAliasFormatterCore

@main
struct TypeAliasFormatterCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "typealias-formatter",
        abstract: "Format a Swift type or export its structure as an SVG graph.",
        discussion: """
        Examples:
          echo 'typealias Body = Pair<A, B>' | typealias-formatter
          typealias-formatter input.txt --indent tab -o output.txt
          typealias-formatter input.txt --format graph -o graph.svg
        """
    )

    @Argument(help: "A UTF-8 input file. Omit it or use '-' to read stdin.")
    var input: String?

    @Option(name: .shortAndLong, help: "An output file. Omit it or use '-' to write to stdout.")
    var output: String?

    @Option(help: "The output format: text or graph (SVG).")
    var format: OutputFormat = .text

    @Option(name: .customLong("indent"), help: "Text indentation: 2, 4, 8, or tab.")
    var indentation: TextIndentation = .fourSpaces

    @Flag(help: "Expand single-argument generics in text output.")
    var expandGenerics = false

    mutating func run() throws {
        let source = try readInput()
        let result = try TypeAliasFormatter().convert(
            source, indentation: indentation.value, expandSingleArguments: expandGenerics
        )
        let text = format == .text ? result.text + "\n" : GraphLayout(root: result.graph).svg
        if let output, output != "-" {
            try text.write(toFile: output, atomically: true, encoding: .utf8)
        } else {
            try FileHandle.standardOutput.write(contentsOf: Data(text.utf8))
        }
    }

    private func readInput() throws -> String {
        let usesStdin = input == nil || input == "-"
        let handle: FileHandle
        if let input, input != "-" {
            handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: input))
        } else {
            guard isatty(STDIN_FILENO) == 0 else {
                throw ValidationError("Provide an input file or pipe a type to stdin. Use --help for examples.")
            }
            handle = .standardInput
        }
        defer { if !usesStdin { try? handle.close() } }

        // Read one byte beyond the limit to reject large files and streams before parsing.
        let limit = TypeAliasFormatter.maximumInputBytes
        var data = Data()
        while data.count <= limit {
            let count = min(65_536, limit + 1 - data.count)
            guard let chunk = try handle.read(upToCount: count), !chunk.isEmpty else { break }
            data.append(chunk)
        }
        guard data.count <= limit else { throw InputError.tooLarge }
        guard let source = String(data: data, encoding: .utf8) else { throw InputError.invalidUTF8 }
        return source
    }
}

private enum InputError: String, LocalizedError {
    case tooLarge = "Input exceeds 200 KB. Format one type at a time."
    case invalidUTF8 = "Input must use UTF-8."

    var errorDescription: String? { rawValue }
}

enum OutputFormat: String, ExpressibleByArgument {
    case text
    case graph
}

enum TextIndentation: String, ExpressibleByArgument {
    case twoSpaces = "2"
    case fourSpaces = "4"
    case eightSpaces = "8"
    case tab

    var value: Indentation {
        switch self {
        case .twoSpaces: .twoSpaces
        case .fourSpaces: .fourSpaces
        case .eightSpaces: .eightSpaces
        case .tab: .tab
        }
    }
}
