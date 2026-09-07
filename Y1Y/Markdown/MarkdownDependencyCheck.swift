import Markdown

struct MarkdownParseSummary: Equatable {
    let containsHeading: Bool
    let containsParagraph: Bool
    let containsCodeBlock: Bool
}

enum MarkdownDependencyCheck {
    static func parseSummary(for source: String) -> MarkdownParseSummary {
        let document = Document(parsing: source)
        let topLevelNodes = Array(document.children)

        return MarkdownParseSummary(
            containsHeading: topLevelNodes.contains { $0 is Heading },
            containsParagraph: topLevelNodes.contains { $0 is Paragraph },
            containsCodeBlock: topLevelNodes.contains { $0 is CodeBlock }
        )
    }
}
