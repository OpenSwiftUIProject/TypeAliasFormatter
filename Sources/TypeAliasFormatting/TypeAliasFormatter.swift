import Foundation

public struct TypeAliasFormatter: Sendable {
    public static let maximumInputBytes = 200_000

    public init() {}

    public func format(
        _ source: String,
        indentation: Indentation = .fourSpaces,
        expandSingleArguments: Bool = false
    ) throws -> String {
        try convert(source, indentation: indentation, expandSingleArguments: expandSingleArguments).text
    }

    public func convert(
        _ source: String,
        indentation: Indentation = .fourSpaces,
        expandSingleArguments: Bool = false
    ) throws -> FormattedType {
        guard source.utf8.count <= Self.maximumInputBytes else {
            throw FormattingError("Input exceeds 200 KB. Format one type at a time.")
        }
        let input = try typeExpression(in: unwrap(source))
        guard !input.isEmpty else {
            throw FormattingError("Enter a typealias declaration or a type.")
        }
        var parser = Parser(input)
        let nodes = try parser.parse()
        let text = Renderer(indentation: indentation, expandSingleArguments: expandSingleArguments)
            .render(nodes, level: 0)
        return FormattedType(text: text, graph: GraphBuilder().build(nodes))
    }

    private func typeExpression(in source: String) throws -> String {
        let input = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = input.split(whereSeparator: \.isWhitespace)
        guard words.filter({ $0 == "typealias" }).count <= 1 else {
            throw FormattingError("Format one typealias declaration at a time.")
        }
        guard input.range(of: #"^(?:(?:public|package|internal|fileprivate|private)\s+)?typealias\b"#,
                          options: .regularExpression) != nil else { return input }
        guard let assignment = input.firstIndex(of: "=") else {
            throw FormattingError("A typealias needs '=' followed by a type.")
        }
        let type = input[input.index(after: assignment)...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !type.isEmpty else { throw FormattingError("A typealias needs '=' followed by a type.") }
        return type
    }

    private func unwrap(_ source: String) throws -> String {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return source }
        let lines = trimmed.components(separatedBy: .newlines)
        guard lines.count >= 3,
              lines.first == "```swift" || lines.first == "```",
              lines.last == "```" else {
            throw FormattingError("Use one complete Swift Markdown code block.")
        }
        return lines.dropFirst().dropLast().joined(separator: "\n")
    }
}

private struct FormattingError: LocalizedError {
    let message: String

    init(_ message: String) { self.message = message }

    var errorDescription: String? { message }
}

private indirect enum Node {
    case text(String)
    case group(Character, [[Node]])

    var hasContent: Bool {
        if case let .text(text) = self {
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    var containsGeneric: Bool {
        guard case let .group(opening, arguments) = self else { return false }
        return opening == "<" || arguments.joined().contains(where: \.containsGeneric)
    }
}

private struct Parser {
    private let characters: [Character]
    private var index = 0

    init(_ source: String) { characters = Array(source) }

    mutating func parse() throws -> [Node] {
        try arguments(closing: nil, depth: 0)[0]
    }

    private mutating func arguments(closing: Character?, depth: Int) throws -> [[Node]] {
        guard depth <= 128 else { throw error("Nesting exceeds 128 levels.") }
        var arguments: [[Node]] = []
        var nodes: [Node] = []
        var text = ""

        func hasContent() -> Bool {
            nodes.contains(where: \.hasContent) || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        func appendText() {
            if !text.isEmpty {
                nodes.append(.text(text))
            }
            text = ""
        }

        while index < characters.count {
            let character = characters[index]
            let next = index + 1 < characters.count ? characters[index + 1] : nil
            // An arrow closes no group, even when there are no surrounding spaces.
            if character == "-", next == ">" {
                text += "->"
                index += 2
                continue
            }
            if character == "/", next == "/" || next == "*" {
                throw error("Remove comments before formatting a type.")
            }
            if character == "`" {
                text.append(character)
                index += 1
                while index < characters.count, characters[index] != "`" {
                    text.append(characters[index])
                    index += 1
                }
                guard index < characters.count else { throw error("Missing closing backtick.") }
                text.append("`")
                index += 1
                continue
            }
            if character == "<" || character == "(" || character == "[" {
                appendText()
                index += 1
                let closing: Character = character == "<" ? ">" : character == "(" ? ")" : "]"
                let children = try self.arguments(closing: closing, depth: depth + 1)
                nodes.append(.group(character, children))
                continue
            }
            if character == "," {
                guard closing != nil else { throw error("A comma must be inside a type argument list or tuple.") }
                guard hasContent() else { throw error("Missing type before ','.") }
                appendText()
                arguments.append(nodes)
                nodes = []
                index += 1
                continue
            }
            if character == ">" || character == ")" || character == "]" {
                guard character == closing else {
                    let expected = closing.map { " Expected '\($0)'." } ?? ""
                    throw error("Unexpected '\(character)'.\(expected)")
                }
                guard hasContent() || (closing == ")" && arguments.isEmpty) else {
                    throw error("Missing type before '\(character)'.")
                }
                appendText()
                arguments.append(nodes)
                index += 1
                return arguments
            }
            text.append(character)
            index += 1
        }
        if let closing { throw error("Missing closing '\(closing)'.") }
        appendText()
        arguments.append(nodes)
        return arguments
    }

    private func error(_ message: String) -> FormattingError {
        let prefix = characters[..<index]
        let line = prefix.filter { $0.isNewline }.count + 1
        let column = index - (prefix.lastIndex(where: \.isNewline) ?? -1)
        return FormattingError("\(message) (line \(line), column \(column))")
    }
}

private struct Renderer {
    let indentation: Indentation
    let expandSingleArguments: Bool

    func render(_ nodes: [Node], level: Int) -> String {
        var output = ""
        for node in nodes {
            switch node {
            case let .text(text):
                output += normalized(text)
            case let .group(opening, arguments):
                let closing = opening == "<" ? ">" : opening == "(" ? ")" : "]"
                if opening == "<" {
                    while output.last?.isWhitespace == true { output.removeLast() }
                    let children = arguments.map { render($0, level: level + 1) }
                    let expanded = expandSingleArguments || children.count > 1 || children.contains { $0.contains("\n") }
                    if expanded {
                        output += "<\n" + indent(level + 1)
                        output += children.joined(separator: ",\n" + indent(level + 1))
                        output += "\n" + indent(level) + ">"
                    } else {
                        output += "<" + children.joined(separator: ", ") + ">"
                    }
                } else {
                    output += String(opening)
                    output += arguments.map { render($0, level: level) }.joined(separator: ", ")
                    output += closing
                }
            }
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func indent(_ level: Int) -> String {
        String(repeating: indentation.unit, count: level)
    }

    private func normalized(_ text: String) -> String {
        let value = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !value.isEmpty else { return text.isEmpty ? "" : " " }
        return (text.first?.isWhitespace == true ? " " : "") + value
            + (text.last?.isWhitespace == true ? " " : "")
    }
}

private struct GraphBuilder {
    func build(_ nodes: [Node]) -> TypeGraphNode {
        var label = ""
        var children: [TypeGraphNode] = []
        var genericCount = 0
        for node in nodes {
            switch node {
            case let .text(text):
                label += text
            case let .group(opening, arguments):
                let closing = opening == "<" ? ">" : opening == "(" ? ")" : "]"
                if opening == "<" {
                    label += "<…>"
                    genericCount += 1
                    children += arguments.map(build)
                } else if node.containsGeneric || arguments.count > 1 {
                    label += String(opening) + "…" + closing
                    children += arguments.map(build)
                } else {
                    label += Renderer(indentation: .fourSpaces, expandSingleArguments: false).render([node], level: 0)
                }
            }
        }
        label = label.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if genericCount == 1, label.hasSuffix("<…>") {
            label.removeLast(3)
            label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return TypeGraphNode(label: label, children: children)
    }
}
