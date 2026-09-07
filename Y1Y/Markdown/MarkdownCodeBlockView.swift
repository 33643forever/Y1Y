import AppKit
import SwiftUI

struct MarkdownCodeBlockView: View {
    let code: String
    let language: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if let language, !language.isEmpty {
                    Text(language)
                        .font(.caption2.monospaced().uppercaseSmallCaps())
                        .foregroundStyle(Color(red: 99/255, green: 99/255, blue: 102/255))
                }

                Spacer(minLength: 8)

                Button {
                    MarkdownCodeBlockCopyAction.copy(code)
                } label: {
                    Label("复制代码", systemImage: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(Color(red: 99/255, green: 99/255, blue: 102/255))
                }
                .buttonStyle(.plain)
                .help("复制此代码块")
                .accessibilityLabel("复制此代码块")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()
                .background(Color(red: 255/255, green: 255/255, blue: 255/255).opacity(0.03))

            Text(code.isEmpty ? " " : code)
                .font(.callout.monospaced())
                .textSelection(.enabled)
                .foregroundStyle(Color(red: 199/255, green: 199/255, blue: 204/255))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
        }
        .background(Color(red: 10/255, green: 10/255, blue: 12/255))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 255/255, green: 255/255, blue: 255/255).opacity(0.04), lineWidth: 0.5)
        }
    }
}

enum MarkdownCodeBlockCopyAction {
    @discardableResult
    static func copy(
        _ code: String,
        to pasteboard: NSPasteboard = .general
    ) -> Bool {
        pasteboard.clearContents()
        return pasteboard.setString(code, forType: .string)
    }
}
