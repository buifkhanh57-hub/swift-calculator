//
//  Parser.swift
//  unitwise
//
//  Expression front-end. Turns command-line text such as
//
//      5 km to mi        5km->mi        72F        3 in to cm        4 GB in MiB
//
//  into a `ConversionRequest`. The pipeline is:
//
//      tokenize (hand-written lexer, no regex)
//        → interpret (category prefix, value, source unit, separator, target)
//        → resolve (exact-case → caseless → plural-stripped alias lookup,
//                   with mutual category anchoring for ambiguous tokens)
//
//  Two conventions worth knowing:
//   * "to" is always a separator; "in" is a separator only when a source
//     unit has already been parsed, so `3 in to cm` (inches) and
//     `4 GB in MiB` (separator) both work.
//   * Ambiguity is resolved by anchoring: when exactly one side of the
//     conversion is unambiguous, the other token is restricted to that
//     category — that is why `72F to c` means celsius while `0.5c to mps`
//     means the speed of light.
//

import Foundation

// MARK: - Token

/// One lexical token with its position in the raw expression.
public struct Token: Equatable {

    /// The kind of token the lexer produced.
    public enum Kind: Equatable {
        /// A numeric literal (already parsed to Double).
        case number(Double)
        /// An identifier (unit or category word, normalized).
        case word(String)
        /// A conversion separator: `to`, `in`, `->`, `=>`, `>`, `=`.
        case separator
    }

    public let kind: Kind
    /// The raw substring the token came from (for error messages).
    public let raw: String
    /// Character offset of the token start inside the raw expression.
    public let offset: Int

    public var description: String {
        switch kind {
        case .number(let value): return "number(\(value))"
        case .word(let word): return "word('\(word)')"
        case .separator: return "separator('\(raw)')"
        }
    }
}

// MARK: - ConversionRequest

/// A fully resolved conversion: value, source unit, target unit, and the
/// category that owns both (guaranteed identical by the parser).
public struct ConversionRequest: Equatable, CustomStringConvertible {

    /// The numeric value to convert.
    public let value: Double
    /// Source unit.
    public let from: Unit
    /// Target unit (same category as `from`).
    public let to: Unit
    /// The owning category, carried for output formatting.
    public let category: Category
    /// The original expression text, as typed.
    public let expression: String

    public var description: String {
        "\(value) \(from.symbol) -> \(to.symbol) [\(category.id)]"
    }
}

// MARK: - ExpressionParser

/// Lexes, interprets, and resolves conversion expressions.
public enum ExpressionParser {

    // MARK: Public entry points

    /// Parses an already-joined expression string.
    ///
    /// `toOverride` is the value of a `--to` flag, if any. When the
    /// expression also contains an inline target, both must resolve to the
    /// same unit, otherwise `conflictingTargets` is thrown.
    public static func parse(expression: String,
                             resolver: UnitResolver,
                             toOverride: String? = nil) throws -> ConversionRequest {
        let tokens = try tokenize(expression)
        return try interpret(tokens,
                             raw: expression,
                             resolver: resolver,
                             toOverride: toOverride)
    }

    /// Convenience wrapper that joins individual command-line arguments.
    /// `unitwise 5 km to mi` and `unitwise "5 km to mi"` end up identical.
    public static func parse(arguments: [String],
                             resolver: UnitResolver,
                             toOverride: String? = nil) throws -> ConversionRequest {
        try parse(expression: arguments.joined(separator: " "),
                  resolver: resolver,
                  toOverride: toOverride)
    }

    // MARK: Normalization

    /// Normalizes a unit/category token: lowercases it and maps look-alike
    /// glyphs (µ/μ → u, Å/å → a) so "µs" and "us" both hit microsecond.
    public static func normalizeToken(_ raw: String) -> String {
        var normalized = ""
        normalized.reserveCapacity(raw.count)
        for character in raw.lowercased() {
            switch character {
            case "µ", "μ":
                normalized.append("u")
            case "Å", "å":
                normalized.append("a")
            default:
                normalized.append(character)
            }
        }
        return normalized
    }

    // MARK: Lexer

    /// Tokenizes the raw expression. Throws `UnitWiseError.parse` on any
    /// character it cannot place, including the offending offset.
    public static func tokenize(_ input: String) throws -> [Token] {
        let characters = Array(input)
        var tokens: [Token] = []
        var index = 0

        while index < characters.count {
            let character = characters[index]

            if character == " " || character == "\t" {
                index += 1
                continue
            }

            // Number start: digit, ".5", or signed form like "-3" / "+.5".
            if isNumberStart(characters, index) {
                index = try scanNumber(into: &tokens, characters: characters, start: index)
                continue
            }

            // Arrow separators.
            if character == "-", peek(characters, index, 1) == ">" {
                tokens.append(Token(kind: .separator, raw: "->", offset: index))
                index += 2
                continue
            }
            if character == "=", peek(characters, index, 1) == ">" {
                tokens.append(Token(kind: .separator, raw: "=>", offset: index))
                index += 2
                continue
            }
            if character == ">" {
                tokens.append(Token(kind: .separator, raw: ">", offset: index))
                index += 1
                continue
            }
            if character == "=" {
                tokens.append(Token(kind: .separator, raw: "=", offset: index))
                index += 1
                continue
            }

            // Identifier: unit or category word.
            if isIdentifierStart(character) {
                let raw = scanIdentifier(characters, from: index)
                tokens.append(Token(kind: .word(normalizeToken(raw)),
                                    raw: raw,
                                    offset: index))
                index += raw.count
                continue
            }

            throw UnitWiseError.parse("unexpected character '\(character)'", offset: index)
        }
        return tokens
    }

    /// ASCII digit test (Character is Comparable across Unicode, but we only
    /// ever accept ASCII digits so `Double(_:)` sees what we scanned).
    static func isDigit(_ character: Character) -> Bool {
        character >= "0" && character <= "9"
    }

    /// Characters that may begin an identifier.
    static func isIdentifierStart(_ character: Character) -> Bool {
        character.isLetter || character == "°" || character == "µ" || character == "μ"
    }

    /// Characters allowed inside an identifier. A "-" directly followed by
    /// ">" terminates the scan so "km->mi" splits cleanly.
    static func isIdentifierContinuation(_ character: Character, next: Character?) -> Bool {
        if character == "-" {
            return !(next == ">") && next != nil
        }
        return isIdentifierStart(character) || isDigit(character)
            || character == "-" || character == "_" || character == "/" || character == "°"
    }

    /// Does a number token start at `index`?
    static func isNumberStart(_ characters: [Character], _ index: Int) -> Bool {
        let character = characters[index]
        if isDigit(character) { return true }
        if character == "." {
            return peek(characters, index, 1).map(isDigit) == true
        }
        if character == "+" || character == "-" {
            guard let next = peek(characters, index, 1) else { return false }
            if isDigit(next) { return true }
            if next == ".", peek(characters, index, 2).map(isDigit) == true { return true }
            return false
        }
        return false
    }

    /// Safe look-ahead returning nil instead of crashing on overrun.
    static func peek(_ characters: [Character], _ index: Int, _ ahead: Int) -> Character? {
        let target = index + ahead
        guard target >= 0, target < characters.count else { return nil }
        return characters[target]
    }

    /// Scans a numeric literal (optional sign, digits with "_" group
    /// separators, optional fraction, optional exponent) into `tokens`.
    /// Returns the index just past the number.
    static func scanNumber(into tokens: inout [Token],
                           characters: [Character],
                           start: Int) throws -> Int {
        var index = start
        var raw = ""

        if characters[index] == "+" || characters[index] == "-" {
            raw.append(characters[index])
            index += 1
        }
        while index < characters.count, isDigit(characters[index]) || characters[index] == "_" {
            raw.append(characters[index])
            index += 1
        }
        if index < characters.count, characters[index] == "." {
            raw.append(".")
            index += 1
            while index < characters.count, isDigit(characters[index]) {
                raw.append(characters[index])
                index += 1
            }
        }
        // Exponent: e/E followed by optional sign and at least one digit.
        if index < characters.count,
           characters[index] == "e" || characters[index] == "E" {
            var lookahead = index + 1
            var exponent = "e"
            if lookahead < characters.count,
               characters[lookahead] == "+" || characters[lookahead] == "-" {
                exponent.append(characters[lookahead])
                lookahead += 1
            }
            if lookahead < characters.count, isDigit(characters[lookahead]) {
                exponent.append(characters[lookahead])
                lookahead += 1
                while lookahead < characters.count, isDigit(characters[lookahead]) {
                    exponent.append(characters[lookahead])
                    lookahead += 1
                }
                raw += exponent
                index = lookahead
            }
        }

        let cleaned = raw.replacingOccurrences(of: "_", with: "")
        guard let value = Double(cleaned), value.isFinite else {
            throw UnitWiseError.parse("invalid number '\(raw)'", offset: start)
        }
        tokens.append(Token(kind: .number(value), raw: raw, offset: start))
        return index
    }

    /// Scans an identifier starting at `from` and returns its raw substring.
    static func scanIdentifier(_ characters: [Character], from start: Int) -> String {
        var raw = ""
        var index = start
        while index < characters.count {
            let character = characters[index]
            let next = peek(characters, index, 1)
            if isIdentifierContinuation(character, next: next) {
                raw.append(character)
                index += 1
            } else {
                break
            }
        }
        return raw
    }

    // MARK: Interpretation

    /// Turns the token stream into a resolved request.
    static func interpret(_ tokens: [Token],
                          raw: String,
                          resolver: UnitResolver,
                          toOverride: String?) throws -> ConversionRequest {
        guard !tokens.isEmpty else {
            throw UnitWiseError.parse("empty expression", offset: nil)
        }
        // Local mutable copy: separator promotion below rewrites tokens.
        var tokens = tokens

        var position = 0
        var scope: Category?

        // Optional leading category prefix ("temperature 72F to c").
        if case .word(let first) = tokens[0].kind,
           tokens.count > 1,
           let category = CategoryRegistry.category(matching: first) {
            scope = category
            position += 1
        }

        // Numeric value.
        guard position < tokens.count, case .number(let value) = tokens[position].kind else {
            let near = position < tokens.count ? tokens[position].raw : ""
            let suffix = near.isEmpty ? "" : " (found '\(near)')"
            throw UnitWiseError.parse("expected a numeric value\(suffix)",
                                      offset: position < tokens.count ? tokens[position].offset : nil)
        }
        position += 1

        // Source unit: any word except the separator word "to".
        var fromToken: String?
        if position < tokens.count, case .word(let word) = tokens[position].kind {
            if word == "to" {
                throw UnitWiseError.parse(
                    "missing source unit (found 'to' where a unit was expected)",
                    offset: tokens[position].offset)
            }
            fromToken = word
            position += 1
        }
        guard let sourceToken = fromToken else {
            throw UnitWiseError.parse("missing source unit after the value",
                                      offset: position < tokens.count ? tokens[position].offset : nil)
        }

        // Promote context separators: "to" always acts as one; "in" acts as
        // one once a source unit has been read and another unit word follows,
        // so both `5 km to mi` and `4 GB in MiB` reach the same code path
        // while `3 in to cm` keeps reading the first "in" as inches.
        if position < tokens.count, case .word(let word) = tokens[position].kind,
           word == "to" || word == "in" {
            var followedByWord = false
            if position + 1 < tokens.count, case .word = tokens[position + 1].kind {
                followedByWord = true
            }
            if word == "to" || followedByWord {
                tokens[position] = Token(kind: .separator,
                                         raw: tokens[position].raw,
                                         offset: tokens[position].offset)
            }
        }

        // Inline separator + target unit.
        var toToken: String?
        if position < tokens.count, case .separator = tokens[position].kind {
            let separatorRaw = tokens[position].raw
            position += 1
            guard position < tokens.count, case .word(let word) = tokens[position].kind else {
                throw UnitWiseError.parse("missing target unit after '\(separatorRaw)'",
                                          offset: position < tokens.count ? tokens[position].offset : nil)
            }
            if word == "to" {
                throw UnitWiseError.parse("expected a unit after '\(separatorRaw)', found 'to'",
                                          offset: tokens[position].offset)
            }
            toToken = word
            position += 1
        } else if position < tokens.count {
            // A word directly after the source unit without a separator.
            throw UnitWiseError.parse(
                "unexpected '\(tokens[position].raw)' — separate units with 'to', 'in', or '->'",
                offset: tokens[position].offset)
        }

        // Everything must be consumed by now.
        if position < tokens.count {
            throw UnitWiseError.parse("unexpected trailing input '\(tokens[position].raw)'",
                                      offset: tokens[position].offset)
        }

        // Apply the --to override.
        if let override = toOverride, !override.isEmpty {
            let normalizedOverride = normalizeToken(override)
            if let inline = toToken {
                if inline != normalizedOverride {
                    throw UnitWiseError.conflictingTargets(first: inline, second: normalizedOverride)
                }
            } else {
                toToken = normalizedOverride
            }
        }

        guard let targetToken = toToken else {
            throw UnitWiseError.missingTarget
        }

        let resolved = try resolvePair(sourceToken, targetToken, scope: scope, resolver: resolver)
        return ConversionRequest(value: value,
                                 from: resolved.from,
                                 to: resolved.to,
                                 category: resolved.category,
                                 expression: raw)
    }

    // MARK: Resolution

    /// Resolves source and target tokens into same-category units.
    ///
    /// When one token is ambiguous but the other is not, the ambiguous one
    /// is anchored to the unambiguous one's category. Two ambiguous tokens
    /// sharing exactly one category are anchored to it; anything left
    /// ambiguous raises `ambiguousUnit`.
    public static func resolvePair(_ fromToken: String,
                                   _ toToken: String,
                                   scope: Category? = nil,
                                   resolver: UnitResolver) throws
        -> (category: Category, from: Unit, to: Unit) {

        var fromCandidates = resolver.candidates(for: fromToken)
        var toCandidates = resolver.candidates(for: toToken)

        // A category prefix narrows both sides.
        if let scope = scope {
            fromCandidates = fromCandidates.filter { $0.categoryID == scope.id }
            toCandidates = toCandidates.filter { $0.categoryID == scope.id }
            if fromCandidates.isEmpty {
                throw UnitWiseError.unknownUnit(
                    fromToken,
                    suggestions: suggestions(for: fromToken, within: scope))
            }
            if toCandidates.isEmpty {
                throw UnitWiseError.unknownUnit(
                    toToken,
                    suggestions: suggestions(for: toToken, within: scope))
            }
        }

        // Mutual anchoring when exactly one side is unambiguous.
        if fromCandidates.count > 1, toCandidates.count == 1 {
            fromCandidates = fromCandidates.filter { $0.categoryID == toCandidates[0].categoryID }
        }
        if toCandidates.count > 1, fromCandidates.count == 1 {
            toCandidates = toCandidates.filter { $0.categoryID == fromCandidates[0].categoryID }
        }
        // Both ambiguous: convert only if they share exactly one category.
        if fromCandidates.count > 1, toCandidates.count > 1 {
            let shared = Set(fromCandidates.map { $0.categoryID })
                .intersection(Set(toCandidates.map { $0.categoryID }))
            if shared.count == 1, let only = shared.first {
                fromCandidates = fromCandidates.filter { $0.categoryID == only }
                toCandidates = toCandidates.filter { $0.categoryID == only }
            }
        }

        guard fromCandidates.count == 1 else {
            if fromCandidates.isEmpty {
                throw UnitWiseError.unknownUnit(
                    fromToken,
                    suggestions: suggestions(for: fromToken, resolver: resolver))
            }
            throw UnitWiseError.ambiguousUnit(fromToken,
                                              candidates: fromCandidates.map { $0.qualifiedName })
        }
        guard toCandidates.count == 1 else {
            if toCandidates.isEmpty {
                throw UnitWiseError.unknownUnit(
                    toToken,
                    suggestions: suggestions(for: toToken, resolver: resolver))
            }
            throw UnitWiseError.ambiguousUnit(toToken,
                                              candidates: toCandidates.map { $0.qualifiedName })
        }

        let from = fromCandidates[0]
        let to = toCandidates[0]
        guard from.categoryID == to.categoryID else {
            throw UnitWiseError.categoryMismatch(from: from.qualifiedName,
                                                 to: to.qualifiedName)
        }
        guard let category = resolver.category(withID: from.categoryID) else {
            throw UnitWiseError.config("category '\(from.categoryID)' missing from resolver")
        }
        return (category, from, to)
    }

    /// Resolves a single token, optionally anchored to a category id.
    /// Used by batch mode where each column resolves independently.
    public static func resolveSingle(_ token: String,
                                     anchor categoryID: String?,
                                     resolver: UnitResolver) throws -> Unit {
        var candidates = resolver.candidates(for: token)
        if let categoryID = categoryID {
            candidates = candidates.filter { $0.categoryID == categoryID }
        }
        guard !candidates.isEmpty else {
            throw UnitWiseError.unknownUnit(
                token,
                suggestions: suggestions(for: token, resolver: resolver, categoryID: categoryID))
        }
        guard candidates.count == 1 else {
            throw UnitWiseError.ambiguousUnit(token,
                                              candidates: candidates.map { $0.qualifiedName })
        }
        return candidates[0]
    }

    // MARK: Suggestions

    /// Levenshtein-based "did you mean" list for an unknown token.
    /// Searches all unit aliases (optionally within one category).
    public static func suggestions(for token: String,
                                   resolver: UnitResolver,
                                   categoryID: String? = nil) -> [String] {
        let target = token.lowercased()
        guard !target.isEmpty else { return [] }
        let limit = target.count <= 3 ? 1 : 2

        var vocabulary: [String]
        if let categoryID = categoryID,
           let category = resolver.category(withID: categoryID) {
            vocabulary = category.allAliasTokens.map { $0.lowercased() }
        } else {
            vocabulary = resolver.vocabulary
        }

        var scored: [(token: String, distance: Int)] = []
        var seen = Set<String>()
        for candidate in vocabulary where !seen.contains(candidate) {
            seen.insert(candidate)
            let distance = levenshtein(target, candidate)
            if distance <= limit {
                scored.append((candidate, distance))
            }
        }
        return scored.sorted { lhs, rhs in
            if lhs.distance != rhs.distance { return lhs.distance < rhs.distance }
            return lhs.token < rhs.token
        }.prefix(5).map { $0.token }
    }

    /// Suggestions restricted to a single category's units.
    static func suggestions(for token: String, within category: Category) -> [String] {
        let target = token.lowercased()
        guard !target.isEmpty else { return [] }
        let limit = target.count <= 3 ? 1 : 2

        var scored: [(token: String, distance: Int)] = []
        var seen = Set<String>()
        for alias in category.allAliasTokens {
            let lowered = alias.lowercased()
            guard !seen.contains(lowered) else { continue }
            seen.insert(lowered)
            let distance = levenshtein(target, lowered)
            if distance <= limit {
                scored.append((lowered, distance))
            }
        }
        return scored.sorted { lhs, rhs in
            if lhs.distance != rhs.distance { return lhs.distance < rhs.distance }
            return lhs.token < rhs.token
        }.prefix(5).map { $0.token }
    }

    /// Classic two-row dynamic-programming edit distance.
    public static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let source = Array(lhs)
        let target = Array(rhs)
        if source.isEmpty { return target.count }
        if target.isEmpty { return source.count }

        var previous = Array(0...target.count)
        var current = Array(repeating: 0, count: target.count + 1)

        for row in 1...source.count {
            current[0] = row
            for column in 1...target.count {
                let substitutionCost = source[row - 1] == target[column - 1] ? 0 : 1
                current[column] = min(
                    previous[column] + 1,
                    current[column - 1] + 1,
                    previous[column - 1] + substitutionCost
                )
            }
            swap(&previous, &current)
        }
        return previous[target.count]
    }
}
