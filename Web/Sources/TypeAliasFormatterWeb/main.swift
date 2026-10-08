import Foundation
import JavaScriptKit
import TypeAliasFormatterCore

private var conversion: FormattedType?
private struct Failure: Encodable { let error: String }
private struct Diagram: Encodable {
    let layout: GraphLayout
    let svg: String
}

private func json<T: Encodable>(_ value: T) -> JSValue {
    // These payloads contain only strings, integers, and finite layout coordinates.
    .string(String(decoding: try! JSONEncoder().encode(value), as: UTF8.self))
}

private let convert = JSClosure { arguments in
    conversion = nil
    do {
        let result = try TypeAliasFormatter().convert(
            arguments[0].string ?? "",
            indentation: Indentation(rawValue: Int(arguments[1].number ?? 4)) ?? .fourSpaces,
            expandSingleArguments: arguments[2].boolean ?? false
        )
        conversion = result
        return json(result)
    } catch {
        return json(Failure(error: error.localizedDescription))
    }
}

private let diagram = JSClosure { arguments in
    guard let conversion else { return .null }
    let data = Data((arguments[0].string ?? "[]").utf8)
    let collapsed = (try? JSONDecoder().decode([String].self, from: data)) ?? []
    let layout = GraphLayout(root: conversion.graph, collapsed: Set(collapsed))
    return json(Diagram(layout: layout, svg: layout.svg))
}

private let select = JSClosure { arguments in
    guard let conversion,
          let lower = arguments[0].number, let upper = arguments[1].number else { return .null }
    let representation: TypeRepresentation = arguments[2].string == "source" ? .source : .formatted
    guard let mapping = conversion.mapping(containing: UTF16Range(Int(lower), Int(upper)), in: representation) else {
        return .null
    }
    return .string(mapping.id)
}

JSObject.global.typeAliasConvert = .object(convert)
JSObject.global.typeAliasDiagram = .object(diagram)
JSObject.global.typeAliasSelect = .object(select)
