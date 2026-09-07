import Foundation
import Markdown

enum MarkdownPlainTextRenderer {
    nonisolated static func unsupportedFootnoteDefinitions(in source: String) -> [String] {
        source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("[^"),
                      let closingMarker = trimmed.range(of: "]:")
                else {
                    return false
                }

                return closingMarker.lowerBound > trimmed.index(
                    trimmed.startIndex,
                    offsetBy: 2
                )
            }
    }

    nonisolated static func text(from markup: Markup) -> String {
        if let text = markup as? Markdown.Text {
            return text.string
        }
        if let inlineCode = markup as? InlineCode {
            return inlineCode.code
        }
        if let codeBlock = markup as? CodeBlock {
            return codeBlock.code
        }
        if let inlineHTML = markup as? InlineHTML {
            return inlineHTML.rawHTML
        }
        if let htmlBlock = markup as? HTMLBlock {
            return htmlBlock.rawHTML
        }
        if markup is SoftBreak || markup is LineBreak {
            return "\n"
        }

        let fragments = markup.children
            .map(text(from:))
            .filter { !$0.isEmpty }

        if markup is Table || markup is Table.Head || markup is Table.Body {
            return fragments.joined(separator: "\n")
        }
        if markup is Table.Row {
            return fragments.joined(separator: " | ")
        }

        return fragments.joined()
    }
}
