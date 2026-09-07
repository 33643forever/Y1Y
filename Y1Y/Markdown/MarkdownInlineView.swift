import Markdown
import SwiftUI

struct MarkdownInlineView: View {
    let source: String

    var body: some View {
        SwiftUI.Text(MarkdownInlineRenderer.render(source))
            .font(.callout)
            .textSelection(.enabled)
    }
}

enum MarkdownInlineRenderer {
    static func render(_ source: String) -> AttributedString {
        let document = Document(parsing: source)
        return renderChildren(of: document)
    }

    static func renderChildren(of markup: Markup) -> AttributedString {
        var result = AttributedString()

        appendChildren(of: markup, context: InlineContext(), to: &result)

        return result
    }

    private static func append(
        _ markup: Markup,
        context: InlineContext,
        to result: inout AttributedString
    ) {
        if let text = markup as? Markdown.Text {
            result.append(attributedString(text.string, context: context))
            return
        }

        if let inlineCode = markup as? InlineCode {
            var codeContext = context
            codeContext.presentationIntent.insert(.code)
            result.append(attributedString(inlineCode.code, context: codeContext))
            return
        }

        if let image = markup as? Markdown.Image {
            let alternativeText = MarkdownPlainTextRenderer.text(from: image)
            let label = alternativeText.isEmpty
                ? "[图片]"
                : "[图片: \(alternativeText)]"
            result.append(attributedString(label, context: context))
            return
        }

        if let inlineHTML = markup as? InlineHTML {
            result.append(attributedString(inlineHTML.rawHTML, context: context))
            return
        }

        if markup is SoftBreak || markup is LineBreak {
            result.append(attributedString("\n", context: context))
            return
        }

        var childContext = context
        if markup is Strong {
            childContext.presentationIntent.insert(.stronglyEmphasized)
        } else if markup is Emphasis {
            childContext.presentationIntent.insert(.emphasized)
        } else if markup is Strikethrough {
            childContext.presentationIntent.insert(.strikethrough)
        } else if let link = markup as? Markdown.Link,
                  let destination = link.destination,
                  let url = URL(string: destination) {
            childContext.link = url
        }

        appendChildren(of: markup, context: childContext, to: &result)
    }

    private static func appendChildren(
        of markup: Markup,
        context: InlineContext,
        to result: inout AttributedString
    ) {
        for child in markup.children {
            append(child, context: context, to: &result)
        }
    }

    private static func attributedString(
        _ text: String,
        context: InlineContext
    ) -> AttributedString {
        var result = AttributedString(text)

        if !context.presentationIntent.isEmpty {
            result.inlinePresentationIntent = context.presentationIntent
        }
        result.link = context.link

        return result
    }

    private struct InlineContext {
        var presentationIntent: InlinePresentationIntent = []
        var link: URL?
    }
}
