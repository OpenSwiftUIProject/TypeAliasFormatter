public enum Indentation: Int, CaseIterable, Sendable {
    case tab = 0
    case twoSpaces = 2
    case fourSpaces = 4
    case eightSpaces = 8

    var unit: String {
        self == .tab ? "\t" : String(repeating: " ", count: rawValue)
    }
}
