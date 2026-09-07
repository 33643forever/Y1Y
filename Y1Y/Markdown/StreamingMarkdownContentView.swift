import AppKit
import SwiftUI

struct StreamingMarkdownContentView: View {
    let snapshot: MarkdownRenderSnapshot
    let fallbackSource: String

    var body: some View {
        let source = snapshot.source.isEmpty
            ? fallbackSource
            : snapshot.source

        Group {
            if snapshot.source.isEmpty || snapshot.presentationMode == .plainText {
                Text(source)
                    .font(.callout)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                MarkdownBlockView(source: source)
            }
        }
    }
}

enum ResponseCopyAction {
    @discardableResult
    static func copy(
        _ rawResponse: String,
        to pasteboard: NSPasteboard = .general
    ) -> Bool {
        pasteboard.clearContents()
        return pasteboard.setString(rawResponse, forType: .string)
    }
}
