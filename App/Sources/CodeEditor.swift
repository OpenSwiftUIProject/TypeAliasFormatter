import AppKit
import SwiftUI

struct CodeEditor: NSViewRepresentable {
    @Binding var text: String
    var editable: Bool
    var accessibilityLabel: String
    var wrapsLines = false

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = NSTextView(frame: .zero)
        textView.isEditable = editable
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = editable
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.defaultParagraphStyle = paragraphStyle
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 18, height: 18)
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]
        textView.delegate = context.coordinator
        textView.setAccessibilityLabel(accessibilityLabel)
        textView.setAccessibilityIdentifier(editable ? "sourceEditor" : "outputEditor")
        scrollView.documentView = textView
        configureWrapping(textView, in: scrollView)
        context.coordinator.wrapsLines = wrapsLines
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if context.coordinator.wrapsLines != wrapsLines {
            configureWrapping(textView, in: scrollView)
            context.coordinator.wrapsLines = wrapsLines
        }
        guard textView.string != text else { return }
        textView.string = text
        if !editable { highlight(textView) }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    private var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        style.tabStops = []
        style.defaultTabInterval = ("    " as NSString).size(withAttributes: [.font: font]).width
        return style
    }

    private func configureWrapping(_ textView: NSTextView, in scrollView: NSScrollView) {
        guard let container = textView.textContainer else { return }
        scrollView.hasHorizontalScroller = !wrapsLines
        textView.isHorizontallyResizable = !wrapsLines
        container.widthTracksTextView = wrapsLines
        if wrapsLines {
            textView.setFrameSize(NSSize(width: scrollView.contentSize.width, height: textView.frame.height))
            container.containerSize = NSSize(
                width: max(0, scrollView.contentSize.width - 2 * textView.textContainerInset.width),
                height: CGFloat.greatestFiniteMagnitude
            )
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: scrollView.contentView.bounds.origin.y))
        } else {
            container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }
        textView.layoutManager?.ensureLayout(for: container)
        textView.sizeToFit()
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func highlight(_ textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let range = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.setAttributes([
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraphStyle,
        ], range: range)
        let patterns: [(String, NSColor)] = [
            (#"\b(typealias|some|any|in|public|private|internal|fileprivate|package|async|throws)\b"#, .systemPurple),
            (#"[<>]"#, .systemBlue),
            (#"\b_[A-Fa-f0-9]{16,}\b|```swift|```"#, .secondaryLabelColor),
        ]
        for (pattern, color) in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in expression.matches(in: textView.string, range: range) {
                storage.addAttribute(.foregroundColor, value: color, range: match.range)
            }
        }
        storage.endEditing()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditor
        var wrapsLines: Bool?

        init(_ parent: CodeEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
