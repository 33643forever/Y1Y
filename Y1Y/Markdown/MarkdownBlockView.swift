import Markdown
import SwiftUI

struct MarkdownBlockView: View {
    let source: String

    var body: some View {
        let document = Document(parsing: source)
        let footnoteDefinitions =
            MarkdownPlainTextRenderer.unsupportedFootnoteDefinitions(in: source)

        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(document.children.enumerated()), id: \.offset) { _, block in
                MarkdownBlockRenderer.view(for: block)
            }

            ForEach(Array(footnoteDefinitions.enumerated()), id: \.offset) { _, definition in
                Text(definition)
                    .font(.callout)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum MarkdownBlockRenderer {
    static func view(for markup: Markup) -> AnyView {
        if let heading = markup as? Heading {
            return AnyView(
                SwiftUI.Text(MarkdownInlineRenderer.renderChildren(of: heading))
                    .font(headingFont(for: heading.level))
                    .foregroundStyle(headingColor(for: heading.level))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            )
        }

        if let paragraph = markup as? Paragraph {
            return AnyView(
                SwiftUI.Text(MarkdownInlineRenderer.renderChildren(of: paragraph))
                    .font(.callout)
                    .foregroundStyle(Color(red: 199/255, green: 199/255, blue: 204/255))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            )
        }

        if let orderedList = markup as? OrderedList {
            return listView(
                items: Array(orderedList.children),
                marker: { index in "\(Int(orderedList.startIndex) + index)." }
            )
        }

        if let unorderedList = markup as? UnorderedList {
            return listView(
                items: Array(unorderedList.children),
                marker: { _ in "•" }
            )
        }

        if let blockQuote = markup as? BlockQuote {
            return AnyView(
                HStack(alignment: .top, spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(red: 255/255, green: 255/255, blue: 255/255).opacity(0.1))
                        .frame(width: 3)

                    childBlocks(of: blockQuote)
                        .foregroundStyle(Color(red: 142/255, green: 142/255, blue: 147/255))
                }
                .padding(.vertical, 2)
            )
        }

        if let codeBlock = markup as? CodeBlock {
            return AnyView(
                MarkdownCodeBlockView(
                    code: codeBlock.code,
                    language: codeBlock.language
                )
            )
        }

        if let htmlBlock = markup as? HTMLBlock {
            return readableFallback(htmlBlock.rawHTML)
        }

        if markup is Markdown.Table {
            return readableFallback(MarkdownPlainTextRenderer.text(from: markup))
        }

        if markup is ThematicBreak {
            return AnyView(
                Divider()
                    .background(Color(red: 255/255, green: 255/255, blue: 255/255).opacity(0.05))
                    .padding(.vertical, 4)
            )
        }

        if markup.childCount > 0 {
            return AnyView(childBlocks(of: markup))
        }

        return readableFallback(MarkdownPlainTextRenderer.text(from: markup))
    }

    private static func listView(
        items: [Markup],
        marker: @escaping (Int) -> String
    ) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 7) {
                        SwiftUI.Text(marker(index))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 16, alignment: .trailing)

                        childBlocks(of: item)
                    }
                }
            }
            .padding(.leading, 4)
        )
    }

    private static func childBlocks(of markup: Markup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(markup.children.enumerated()), id: \.offset) { _, child in
                view(for: child)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func headingFont(for level: Int) -> Font {
        switch level {
        case 1:
            return .title2.bold()
        case 2:
            return .title3.bold()
        case 3:
            return .headline
        default:
            return .subheadline.bold()
        }
    }

    private static func headingColor(for level: Int) -> Color {
        switch level {
        case 1:
            return Color(red: 245/255, green: 245/255, blue: 247/255)
        case 2:
            return Color(red: 232/255, green: 232/255, blue: 236/255)
        default:
            return Color(red: 232/255, green: 232/255, blue: 236/255)
        }
    }

    private static func readableFallback(_ text: String) -> AnyView {
        AnyView(
            Text(text)
                .font(.callout)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        )
    }
}
