//
//  Errors.swift
//  unitwise
//
//  The unified error type for the whole CLI. Every failure path funnels
//  through `UnitWiseError`, which carries:
//    * a human-readable message      (`CustomStringConvertible`)
//    * an optional remediation hint  (`hint`)
//    * the process exit code         (`exitCode`)
//
//  Exit-code contract (mirrored in `--help` and README.md):
//    0   success
//    1   usage error        — bad flags, unknown command/category, bad --digits
//    2   conversion error   — bad expression, unknown/ambiguous unit, mismatch
//    3   partial batch fail — at least one CSV row could not be converted
//    4   I/O error          — unreadable input file, unwritable output/history
//    70  internal config    — registry invariants violated (should never happen)
//

import Foundation

/// The single error enum used across unitwise.
public enum UnitWiseError: Error, CustomStringConvertible {

    // MARK: Usage errors (exit 1)

    /// Generic command-line misuse with a free-form explanation.
    case usage(String)
    /// A command word that unitwise does not know, plus close matches.
    case unknownCommand(String, suggestions: [String])
    /// A flag that unitwise does not know.
    case unknownFlag(String)
    /// A value-taking flag invoked without its value.
    case missingFlagValue(String)
    /// `--digits` was not an integer inside 1...15.
    case invalidPrecision(String)
    /// A category name given to `list`/`table` that does not resolve.
    case unknownCategory(String, suggestions: [String])

    // MARK: Conversion errors (exit 2)

    /// The expression could not be tokenized or interpreted.
    case parse(String, offset: Int?)
    /// A unit token matched nothing; carries Levenshtein suggestions.
    case unknownUnit(String, suggestions: [String])
    /// A unit token matched several units across categories.
    case ambiguousUnit(String, candidates: [String])
    /// Source and target units live in different categories.
    case categoryMismatch(from: String, to: String)
    /// The expression had no target unit and no `--to` override.
    case missingTarget
    /// Both an inline target and `--to` were given, and they disagree.
    case conflictingTargets(first: String, second: String)
    /// A value that should be numeric is not (batch cells, --value).
    case invalidNumber(String)
    /// The conversion produced NaN or infinity.
    case numericOverflow

    // MARK: I/O and batch errors

    /// Filesystem failure with context.
    case io(String)
    /// A batch run finished with some rows failing.
    case batchPartial(failed: Int, total: Int)

    // MARK: Internal

    /// Registry invariant violation — a programming bug, not a user error.
    case config(String)

    // MARK: Exit code

    /// The exit code the CLI should terminate with for this error.
    public var exitCode: Int {
        switch self {
        case .usage, .unknownCommand, .unknownFlag, .missingFlagValue,
             .invalidPrecision, .unknownCategory:
            return 1
        case .parse, .unknownUnit, .ambiguousUnit, .categoryMismatch,
             .missingTarget, .conflictingTargets, .invalidNumber,
             .numericOverflow:
            return 2
        case .batchPartial:
            return 3
        case .io:
            return 4
        case .config:
            return 70
        }
    }

    // MARK: Hint

    /// An optional second line suggesting how to fix the problem.
    public var hint: String? {
        switch self {
        case .usage, .missingTarget, .unknownCategory:
            return "Try 'unitwise --help' for usage examples."
        case .unknownCommand(_, let suggestions):
            return UnitWiseError.didYouMean(suggestions).map { "Did you mean \($0)?" }
        case .unknownUnit(_, let suggestions):
            return UnitWiseError.didYouMean(suggestions).map { "Did you mean \($0)?" }
        case .unknownFlag:
            return "Run 'unitwise --help' to list the available flags."
        case .ambiguousUnit:
            return "Disambiguate with a category prefix, e.g. 'unitwise temperature 72F to c'."
        case .categoryMismatch:
            return "Source and target units must belong to the same measurement category."
        case .batchPartial:
            return "Failing rows carry status=error in the CSV output."
        default:
            return nil
        }
    }

    // MARK: Description

    /// Full single-line message, ready to print to stderr.
    public var description: String {
        switch self {
        case .usage(let message):
            return "usage error: \(message)"
        case .unknownCommand(let name, _):
            return "unknown command '\(name)'"
        case .unknownFlag(let flag):
            return "unknown flag '\(flag)'"
        case .missingFlagValue(let flag):
            return "flag '\(flag)' expects a value (e.g. '\(flag) 4' or '\(flag)=4')"
        case .invalidPrecision(let raw):
            return "--digits expects an integer between 1 and 15, got '\(raw)'"
        case .unknownCategory(let name, let suggestions):
            var message = "unknown category '\(name)'"
            if let suffix = UnitWiseError.didYouMean(suggestions) {
                message += suffix
            }
            return message
        case .parse(let message, let offset):
            if let offset = offset {
                return "parse error: \(message) (near character \(offset + 1))"
            }
            return "parse error: \(message)"
        case .unknownUnit(let token, let suggestions):
            var message = "unknown unit '\(token)'"
            if let suffix = UnitWiseError.didYouMean(suggestions) {
                message += suffix
            }
            return message
        case .ambiguousUnit(let token, let candidates):
            let listed = candidates.map { "'\($0)'" }.joined(separator: ", ")
            return "ambiguous unit '\(token)': matches \(listed)"
        case .categoryMismatch(let from, let to):
            return "cannot convert from '\(from)' to '\(to)': different measurement categories"
        case .missingTarget:
            return "no target unit: append 'to <unit>' or '-> <unit>', or pass --to"
        case .conflictingTargets(let first, let second):
            return "two different targets given: '\(first)' and '\(second)'"
        case .invalidNumber(let raw):
            return "'\(raw)' is not a valid number"
        case .numericOverflow:
            return "conversion produced a non-finite result (overflow)"
        case .io(let message):
            return "I/O error: \(message)"
        case .batchPartial(let failed, let total):
            return "batch finished with \(failed) of \(total) rows failing"
        case .config(let message):
            return "internal configuration error: \(message)"
        }
    }

    // MARK: Helpers

    /// Renders a suggestion list as " — did you mean 'a', 'b'?" or nil.
    static func didYouMean(_ suggestions: [String]) -> String? {
        guard !suggestions.isEmpty else { return nil }
        let quoted = suggestions.map { "'\($0)'" }.joined(separator: ", ")
        return " — did you mean \(quoted)?"
    }
}
