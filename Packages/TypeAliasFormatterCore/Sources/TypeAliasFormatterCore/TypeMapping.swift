/// A half-open UTF-16 range shared by native text views and browser editors.
public struct UTF16Range: Codable, Equatable, Sendable {
    public let lowerBound: Int
    public let upperBound: Int

    public init(_ lowerBound: Int, _ upperBound: Int) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    public var count: Int { upperBound - lowerBound }

    public func contains(_ selection: UTF16Range) -> Bool {
        selection.lowerBound >= lowerBound && selection.upperBound <= upperBound
            && selection.lowerBound < upperBound && selection.count >= 0
    }
}

public struct TypeMapping: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let sourceRange: UTF16Range
    public let formattedRange: UTF16Range
}

public enum TypeRepresentation: Sendable {
    case source
    case formatted
}

extension FormattedType {
    public func mapping(containing selection: UTF16Range, in representation: TypeRepresentation) -> TypeMapping? {
        func range(_ mapping: TypeMapping) -> UTF16Range {
            representation == .source ? mapping.sourceRange : mapping.formattedRange
        }
        return mappings.filter { range($0).contains(selection) }.min { range($0).count < range($1).count }
    }
}
