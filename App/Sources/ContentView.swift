import AppKit
import SwiftUI
import TypeAliasFormatterCore
import UniformTypeIdentifiers

private enum OutputMode: String, CaseIterable, Identifiable {
    case text = "Text"
    case graph = "Graph"

    var id: Self { self }
    var fileExtension: String { self == .text ? "txt" : "svg" }
    var contentType: UTType { UTType(filenameExtension: fileExtension) ?? .plainText }
}

private struct FormatRequest: Hashable, Sendable {
    let source: String
    let indentation: Indentation
    let expandSingleArguments: Bool
    let revision: Int
}

struct ContentView: View {
    @State private var source = ""
    @State private var formatted = ""
    @State private var graph: TypeGraphNode?
    @State private var collapsedNodes: Set<String> = []
    @State private var completedRequest: FormatRequest?
    @State private var formatError: String?
    @State private var fileError: String?
    @State private var revision = 0
    @State private var copied = false
    @AppStorage("indentation") private var indentation: Indentation = .fourSpaces
    @AppStorage("wrapSourceLines") private var wrapSourceLines = true
    @AppStorage("expandSingleArguments") private var expandSingleArguments = false
    @AppStorage("presentationMode") private var outputMode: OutputMode = .text

    private var request: FormatRequest {
        FormatRequest(source: source, indentation: indentation,
                      expandSingleArguments: expandSingleArguments, revision: revision)
    }

    private var isCurrent: Bool { completedRequest == request }
    private var canExport: Bool { isCurrent && formatError == nil && !formatted.isEmpty }
    private var output: String {
        guard canExport else { return "" }
        return formatted
    }

    private var graphLayout: GraphLayout? {
        graph.map { GraphLayout(root: $0, collapsed: collapsedNodes) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                editorPane(title: "Source", subtitle: "Swift typealias or demangled type", isInput: true)
                    .frame(minWidth: 300, idealWidth: 430)
                editorPane(title: "Formatted", subtitle: "Nested generic arguments", isInput: false)
                    .frame(minWidth: 400, idealWidth: 810)
            }
            Divider()
            statusBar
        }
        .frame(minWidth: 850, minHeight: 480)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: openFile) { Label("Open", systemImage: "folder") }
                    .help("Open a Swift, Markdown, or text file")
                    .keyboardShortcut("o")
            }
            ToolbarItemGroup {
                if outputMode == .text {
                    Picker("Indentation", selection: $indentation) {
                        Text("2 spaces").tag(Indentation.twoSpaces)
                        Text("4 spaces").tag(Indentation.fourSpaces)
                        Text("8 spaces").tag(Indentation.eightSpaces)
                        Text("Tab").tag(Indentation.tab)
                    }
                    .frame(width: 115)
                    .help("Indentation per generic level")

                    Toggle(isOn: $expandSingleArguments) {
                        Label("Expand generics", systemImage: "arrow.up.and.down.text.horizontal")
                    }
                    .help("Also expand single-argument generics in text")
                }

                Button { revision += 1 } label: { Label("Format", systemImage: "text.alignleft") }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Divider()
                Button(action: copyOutput) {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(!canExport)
                .help(outputMode == .text ? "Copy formatted text" : "Copy the visible graph as SVG")

                Button(action: saveFile) { Label("Save", systemImage: "square.and.arrow.down") }
                    .keyboardShortcut("s")
                    .disabled(!canExport)
            }
        }
        .task(id: request) { await format(request) }
        .onChange(of: output) { copied = false }
        .onChange(of: outputMode) { copied = false }
        .onChange(of: collapsedNodes) { copied = false }
        .alert("File operation failed", isPresented: Binding(
            get: { fileError != nil },
            set: { if !$0 { fileError = nil } }
        )) {
            Button("OK") { fileError = nil }
        } message: {
            Text(fileError ?? "")
        }
    }

    private func editorPane(title: String, subtitle: String, isInput: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if isInput {
                    Toggle("Wrap lines", isOn: $wrapSourceLines)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                        .fixedSize()
                        .help("Wrap source lines to the editor width")
                    Button("Clear") { source = "" }
                        .buttonStyle(.borderless)
                        .disabled(source.isEmpty)
                } else {
                    Picker("Output format", selection: $outputMode) {
                        ForEach(OutputMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 170)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.bar)
            Divider()
            if !isInput, outputMode == .graph, canExport, let graph, let graphLayout {
                TypeGraphView(root: graph, layout: graphLayout, collapsed: $collapsedNodes)
            } else {
                ZStack(alignment: .topLeading) {
                    CodeEditor(text: isInput ? $source : .constant(output),
                               editable: isInput, accessibilityLabel: isInput ? "Source typealias" : "Formatted output",
                               wrapsLines: isInput && wrapSourceLines)
                    if (isInput ? source : output).isEmpty {
                        Text(isInput ? "Paste a typealias or type here…" : "Converted output appears here.")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(20)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            if isCurrent, let formatError {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                Text(formatError).textSelection(.enabled)
            } else if source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Paste a type to begin.").foregroundStyle(.secondary)
            } else if !isCurrent {
                ProgressView().controlSize(.small)
                Text("Formatting…").foregroundStyle(.secondary)
            } else {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("\(formatted.components(separatedBy: "\n").count) lines")
                Text("·  Private type names preserved").foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text("\(source.count.formatted()) characters").foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func format(_ request: FormatRequest) async {
        do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
        guard !Task.isCancelled else { return }
        if request.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            formatted = ""
            graph = nil
            formatError = nil
            completedRequest = request
            return
        }
        let result = await Task.detached(priority: .userInitiated) {
            Result {
                try TypeAliasFormatter().convert(request.source, indentation: request.indentation,
                                                 expandSingleArguments: request.expandSingleArguments)
            }
        }.value
        guard !Task.isCancelled else { return }
        switch result {
        case let .success(value):
            formatted = value.text
            if graph != value.graph {
                graph = value.graph
                collapsedNodes = Set(GraphLayout(root: value.graph).nodes.filter {
                    $0.id.split(separator: ".").count >= 3 && $0.childCount > 0
                }.map(\.id))
            }
            formatError = nil
        case let .failure(error):
            formatted = ""
            graph = nil
            formatError = error.localizedDescription
        }
        completedRequest = request
    }

    private func copyOutput() {
        guard canExport else { return }
        NSPasteboard.general.clearContents()
        if outputMode == .graph, let graphLayout {
            let svg = graphLayout.svg
            NSPasteboard.general.setData(Data(svg.utf8), forType: NSPasteboard.PasteboardType(UTType.svg.identifier))
            NSPasteboard.general.setString(svg, forType: .string)
        } else {
            NSPasteboard.general.setString(output, forType: .string)
        }
        copied = true
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.text, .sourceCode]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= TypeAliasFormatter.maximumInputBytes else {
                fileError = "Input exceeds 200 KB. Open a file that contains one type."
                return
            }
            source = try String(contentsOf: url, encoding: .utf8)
        } catch { fileError = error.localizedDescription }
    }

    private func saveFile() {
        guard canExport else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [outputMode.contentType]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "FormattedTypealias.\(outputMode.fileExtension)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let content = outputMode == .graph ? graphLayout?.svg ?? "" : output + "\n"
        do { try content.write(to: url, atomically: true, encoding: .utf8) }
        catch { fileError = error.localizedDescription }
    }
}
