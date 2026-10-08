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
        var parser = Parser(String(input), offset: source[..<input.startIndex].utf16.count)
        let nodes = try parser.parse()
        let text = Renderer(indentation: indentation, expandSingleArguments: expandSingleArguments)
            .render(nodes, level: 0)
        var sourceRanges: [String: UTF16Range] = [:]
        let graph = GraphBuilder().build(nodes, ranges: &sourceRanges)
        var outputParser = Parser(text)
        var formattedRanges: [String: UTF16Range] = [:]
        _ = GraphBuilder().build(try outputParser.parse(), ranges: &formattedRanges)
        let mappings = sourceRanges.keys.sorted().map { id in
            TypeMapping(id: id, sourceRange: sourceRanges[id]!, formattedRange: formattedRanges[id]!)
        }
        return FormattedType(text: text, graph: graph, mappings: mappings)
    }

    private func typeExpression(in source: Substring) throws -> Substring {
        let input = trimmed(source)
        let words = input.split(whereSeparator: \.isWhitespace)
        guard words.filter({ $0 == "typealias" }).count <= 1 else {
            throw FormattingError("Format one typealias declaration at a time.")
        }
        guard String(input).range(of: #"^(?:(?:public|package|internal|fileprivate|private)\s+)?typealias\b"#,
                          options: .regularExpression) != nil else { return input }
        guard let assignment = input.firstIndex(of: "=") else {
            throw FormattingError("A typealias needs '=' followed by a type.")
        }
        let type = trimmed(input[input.index(after: assignment)...])
        guard !type.isEmpty else { throw FormattingError("A typealias needs '=' followed by a type.") }
        return type
    }

    private func unwrap(_ source: String) throws -> Substring {
        let input = trimmed(source[...])
        guard input.hasPrefix("```") else { return input }
        guard let firstNewline = input.firstIndex(where: \.isNewline),
              let lastNewline = input.lastIndex(where: \.isNewline),
              firstNewline < lastNewline,
              input[..<firstNewline] == "```swift" || input[..<firstNewline] == "```",
              input[input.index(after: lastNewline)...] == "```" else {
            throw FormattingError("Use one complete Swift Markdown code block.")
        }
        return input[input.index(after: firstNewline)..<lastNewline]
    }
}

private func trimmed(_ value: Substring) -> Substring {
    var start = value.startIndex
    var end = value.endIndex
    while start < end, value[start].isWhitespace { start = value.index(after: start) }
    while start < end, value[value.index(before: end)].isWhitespace { end = value.index(before: end) }
    return value[start..<end]
}

private struct FormattingError: LocalizedError {
    let message: String

    init(_ message: String) { self.message = message }

    var errorDescription: String? { message }
}

private indirect enum Node {
    case text(String, UTF16Range)
    case group(Character, [[Node]], UTF16Range)

    var range: UTF16Range {
        switch self {
        case let .text(_, range), let .group(_, _, range): range
        }
    }

    var hasContent: Bool {
        if case let .text(text, _) = self {
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    var containsGeneric: Bool {
        guard case let .group(opening, arguments, _) = self else { return false }
        return opening == "<" || arguments.joined().contains(where: \.containsGeneric)
    }
}

private struct Parser {
    private let characters: [Character]
    private var index = 0
    private let offsets: [Int]

    init(_ source: String, offset: Int = 0) {
        characters = Array(source)
        var offsets = [offset]
        for character in characters { offsets.append(offsets.last! + character.utf16.count) }
        self.offsets = offsets
    }

    private func range(_ start: Int, _ end: Int) -> UTF16Range {
        UTF16Range(offsets[start], offsets[end])
    }

    private struct Frame {
        let opening: Character?
        let start: Int
        var arguments: [[Node]] = []
        var nodes: [Node] = []
        var text = ""
        var textStart = 0

        var closing: Character? {
            switch opening {
            case "<": ">"
            case "(": ")"
            case "[": "]"
            default: nil
            }
        }

        var hasContent: Bool {
            nodes.contains(where: \.hasContent) || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        mutating func appendText(end: Int, characters: [Character], offsets: [Int]) {
            if !text.isEmpty {
                var start = textStart
                var end = end
                while start < end, characters[start].isWhitespace { start += 1 }
                while start < end, characters[end - 1].isWhitespace { end -= 1 }
                nodes.append(.text(text, UTF16Range(offsets[start], offsets[end])))
            }
            text = ""
        }
    }

    mutating func parse() throws -> [Node] {
        // Keep nested argument state off the thread stack, including in Debug builds.
        var frames = [Frame(opening: nil, start: 0)]
        while index < characters.count {
            let top = frames.count - 1
            if frames[top].text.isEmpty { frames[top].textStart = index }
            let character = characters[index]
            let next = index + 1 < characters.count ? characters[index + 1] : nil
            // An arrow closes no group, even when there are no surrounding spaces.
            if character == "-", next == ">" {
                frames[top].text += "->"
                index += 2
                continue
            }
            if character == "/", next == "/" || next == "*" {
                throw error("Remove comments before formatting a type.")
            }
            if character == "`" {
                frames[top].text.append(character)
                index += 1
                while index < characters.count, characters[index] != "`" {
                    frames[top].text.append(characters[index])
                    index += 1
                }
                guard index < characters.count else { throw error("Missing closing backtick.") }
                frames[top].text.append("`")
                index += 1
                continue
            }
            if character == "<" || character == "(" || character == "[" {
                frames[top].appendText(end: index, characters: characters, offsets: offsets)
                let start = index
                index += 1
                guard frames.count <= 128 else { throw error("Nesting exceeds 128 levels.") }
                frames.append(Frame(opening: character, start: start))
                continue
            }
            if character == "," {
                guard frames[top].closing != nil else { throw error("A comma must be inside a type argument list or tuple.") }
                guard frames[top].hasContent else { throw error("Missing type before ','.") }
                frames[top].appendText(end: index, characters: characters, offsets: offsets)
                frames[top].arguments.append(frames[top].nodes)
                frames[top].nodes = []
                index += 1
                continue
            }
            if character == ">" || character == ")" || character == "]" {
                let closing = frames[top].closing
                guard character == closing else {
                    let expected = closing.map { " Expected '\($0)'." } ?? ""
                    throw error("Unexpected '\(character)'.\(expected)")
                }
                guard frames[top].hasContent || (closing == ")" && frames[top].arguments.isEmpty) else {
                    throw error("Missing type before '\(character)'.")
                }
                frames[top].appendText(end: index, characters: characters, offsets: offsets)
                var frame = frames.removeLast()
                frame.arguments.append(frame.nodes)
                index += 1
                frames[frames.count - 1].nodes.append(.group(frame.opening!, frame.arguments, range(frame.start, index)))
                continue
            }
            frames[top].text.append(character)
            index += 1
        }
        if let closing = frames.last?.closing { throw error("Missing closing '\(closing)'.") }
        frames[0].appendText(end: index, characters: characters, offsets: offsets)
        return frames[0].nodes
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
            case let .text(text, _):
                output += normalized(text)
            case let .group(opening, arguments, _):
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
    func build(_ nodes: [Node], id: String = "root", ranges: inout [String: UTF16Range]) -> TypeGraphNode {
        if let first = nodes.first(where: \.hasContent), let last = nodes.last(where: \.hasContent) {
            ranges[id] = UTF16Range(first.range.lowerBound, last.range.upperBound)
        }
        var label = ""
        var children: [TypeGraphNode] = []
        var genericCount = 0
        for node in nodes {
            switch node {
            case let .text(text, _):
                label += text
            case let .group(opening, arguments, _):
                let closing = opening == "<" ? ">" : opening == "(" ? ")" : "]"
                if opening == "<" {
                    label += "<…>"
                    genericCount += 1
                    for argument in arguments {
                        children.append(build(argument, id: "\(id).\(children.count)", ranges: &ranges))
                    }
                } else if node.containsGeneric || arguments.count > 1 {
                    label += String(opening) + "…" + closing
                    for argument in arguments {
                        children.append(build(argument, id: "\(id).\(children.count)", ranges: &ranges))
                    }
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
