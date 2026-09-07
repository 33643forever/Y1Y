import Foundation

enum MarkdownPresentationMode: Equatable, Sendable {
    case markdown
    case plainText
}

enum MarkdownStreamingFallbackPolicy {
    nonisolated static func presentationMode(
        for source: String,
        isFinal: Bool
    ) -> MarkdownPresentationMode {
        guard !isFinal else { return .markdown }

        if hasUnclosedFence(in: source)
            || hasUnclosedEmphasis(in: source)
            || hasUnclosedLink(in: source) {
            return .plainText
        }

        return .markdown
    }

    nonisolated private static func hasUnclosedFence(in source: String) -> Bool {
        var openFence: (character: Character, length: Int)?

        for line in source.split(
            separator: "\n",
            omittingEmptySubsequences: false
        ) {
            let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
            guard let first = trimmed.first, first == "`" || first == "~" else {
                continue
            }

            let length = trimmed.prefix(while: { $0 == first }).count
            guard length >= 3 else { continue }

            if let activeFence = openFence {
                if first == activeFence.character && length >= activeFence.length {
                    openFence = nil
                }
            } else {
                openFence = (first, length)
            }
        }

        return openFence != nil
    }

    nonisolated private static func hasUnclosedEmphasis(
        in source: String
    ) -> Bool {
        let lines = source.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        var strongAsterisks = 0
        var strongUnderscores = 0
        var strikethrough = 0
        var singleAsterisks = 0
        var singleUnderscores = 0

        for line in lines {
            var index = line.startIndex
            while index < line.endIndex {
                let character = line[index]
                if character == "\\" {
                    index = line.index(after: index)
                    if index < line.endIndex {
                        index = line.index(after: index)
                    }
                    continue
                }

                let remainder = line[index...]
                if remainder.hasPrefix("**") {
                    if delimiterShouldCount(
                        in: line,
                        at: index,
                        length: 2,
                        character: "*"
                    ) {
                        strongAsterisks += 1
                    }
                    index = line.index(index, offsetBy: 2)
                } else if remainder.hasPrefix("__") {
                    if delimiterShouldCount(
                        in: line,
                        at: index,
                        length: 2,
                        character: "_"
                    ) {
                        strongUnderscores += 1
                    }
                    index = line.index(index, offsetBy: 2)
                } else if remainder.hasPrefix("~~") {
                    if delimiterShouldCount(
                        in: line,
                        at: index,
                        length: 2,
                        character: "~"
                    ) {
                        strikethrough += 1
                    }
                    index = line.index(index, offsetBy: 2)
                } else if character == "*" {
                    let next = line.index(after: index)
                    let isListMarker =
                        index == line.startIndex
                        && next < line.endIndex
                        && line[next].isWhitespace
                    if !isListMarker,
                       delimiterShouldCount(
                           in: line,
                           at: index,
                           length: 1,
                           character: "*"
                       ) {
                        singleAsterisks += 1
                    }
                    index = next
                } else if character == "_" {
                    if delimiterShouldCount(
                        in: line,
                        at: index,
                        length: 1,
                        character: "_"
                    ) {
                        singleUnderscores += 1
                    }
                    index = line.index(after: index)
                } else {
                    index = line.index(after: index)
                }
            }
        }

        return strongAsterisks.isMultiple(of: 2) == false
            || strongUnderscores.isMultiple(of: 2) == false
            || strikethrough.isMultiple(of: 2) == false
            || singleAsterisks.isMultiple(of: 2) == false
            || singleUnderscores.isMultiple(of: 2) == false
    }

    nonisolated private static func delimiterShouldCount(
        in line: Substring,
        at index: Substring.Index,
        length: Int,
        character: Character
    ) -> Bool {
        let end = line.index(index, offsetBy: length)
        let previous = index > line.startIndex
            ? line[line.index(before: index)]
            : nil
        let next = end < line.endIndex ? line[end] : nil

        if character == "_",
           (previous?.isLetter == true || previous?.isNumber == true),
           (next?.isLetter == true || next?.isNumber == true) {
            return false
        }

        let canOpen = next.map { !$0.isWhitespace } ?? false
        let canClose = previous.map { !$0.isWhitespace } ?? false
        return canOpen || canClose
    }

    nonisolated private static func hasUnclosedLink(in source: String) -> Bool {
        var bracketDepth = 0
        var pendingDestination = false
        var destinationDepth = 0
        var index = source.startIndex

        while index < source.endIndex {
            let character = source[index]
            if character == "\\" {
                index = source.index(after: index)
                if index < source.endIndex {
                    index = source.index(after: index)
                }
                continue
            }

            if pendingDestination {
                if character == "(" {
                    destinationDepth += 1
                } else if character == ")" {
                    destinationDepth -= 1
                    if destinationDepth == 0 {
                        pendingDestination = false
                    }
                }
            } else if character == "[" {
                bracketDepth += 1
            } else if character == "]" && bracketDepth > 0 {
                bracketDepth -= 1
                let next = source.index(after: index)
                if next < source.endIndex, source[next] == "(" {
                    pendingDestination = true
                    destinationDepth = 1
                    index = next
                }
            }

            index = source.index(after: index)
        }

        return bracketDepth > 0 || pendingDestination
    }
}
