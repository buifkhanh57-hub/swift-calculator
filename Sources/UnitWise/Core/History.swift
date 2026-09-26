//
//  History.swift
//  unitwise
//
//  Persistent conversion history, stored as a single JSON array at
//  ~/.unitwise/history.json (override the directory for tests).
//
//  Design notes:
//    * One file, one array — small histories make a database pointless, and
//      a single JSON document stays human-inspectable.
//    * Loading is TOLERANT: a missing, empty, or corrupt file yields an
//      empty list instead of an error, because a broken history must never
//      block a conversion. Only writing failures surface as `io` errors.
//    * Every append rewrites the whole file (atomic .atomic write) and
//      trims to `limit` (default 200) entries, oldest first, so the file
//      cannot grow without bounds.
//    * Timestamps are ISO-8601 UTC strings, so the file is diffable and
//      sortable as plain text.
//
//  Exit-code contract: failures here are `UnitWiseError.io` → exit 4, as
//  documented in Errors.swift.
//

import Foundation

// MARK: - HistoryEntry

/// One recorded conversion. Plain value type; JSON mapping is explicit.
public struct HistoryEntry: Equatable {

    /// ISO-8601 UTC formatter shared by every entry; deterministic stamps.
    public static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// When the conversion ran, ISO-8601 UTC.
    public let timestamp: String
    /// The expression exactly as typed.
    public let expression: String
    /// Category identifier ("length", "temperature", ...).
    public let category: String
    /// The numeric input value.
    public let inputValue: Double
    /// Source unit symbol, e.g. "km".
    public let fromSymbol: String
    /// Target unit symbol, e.g. "mi".
    public let toSymbol: String
    /// Converted value (unrounded).
    public let result: Double
    /// Whether the round trip reproduced the input.
    public let exact: Bool

    /// Full memberwise initializer.
    public init(timestamp: String,
                expression: String,
                category: String,
                inputValue: Double,
                fromSymbol: String,
                toSymbol: String,
                result: Double,
                exact: Bool) {
        self.timestamp = timestamp
        self.expression = expression
        self.category = category
        self.inputValue = inputValue
        self.fromSymbol = fromSymbol
        self.toSymbol = toSymbol
        self.result = result
        self.exact = exact
    }

    /// Convenience factory that stamps the current UTC time.
    public static func make(expression: String,
                            category: String,
                            inputValue: Double,
                            fromSymbol: String,
                            toSymbol: String,
                            result: Double,
                            exact: Bool) -> HistoryEntry {
        HistoryEntry(timestamp: timestampFormatter.string(from: Date()),
                     expression: expression,
                     category: category,
                     inputValue: inputValue,
                     fromSymbol: fromSymbol,
                     toSymbol: toSymbol,
                     result: result,
                     exact: exact)
    }

    /// Convenience factory from a fully evaluated conversion.
    public static func make(request: ConversionRequest,
                            result: ConversionResult) -> HistoryEntry {
        HistoryEntry.make(expression: request.expression,
                          category: request.category.id,
                          inputValue: request.value,
                          fromSymbol: request.from.symbol,
                          toSymbol: request.to.symbol,
                          result: result.result,
                          exact: result.exact)
    }

    /// JSON-object projection used by `HistoryStore`.
    public var dictionary: [String: Any] {
        [
            "timestamp": timestamp,
            "expression": expression,
            "category": category,
            "inputValue": inputValue,
            "fromSymbol": fromSymbol,
            "toSymbol": toSymbol,
            "result": result,
            "exact": exact
        ]
    }

    /// Rebuilds an entry from a JSON object; nil when required fields are
    /// missing or mistyped. Tolerates NSNumber/Int/Double number variants
    /// across Foundation builds.
    public static func decode(_ dictionary: [String: Any]) -> HistoryEntry? {
        guard let timestamp = dictionary["timestamp"] as? String,
              let expression = dictionary["expression"] as? String,
              let category = dictionary["category"] as? String,
              let fromSymbol = dictionary["fromSymbol"] as? String,
              let toSymbol = dictionary["toSymbol"] as? String,
              let inputValue = numberValue(dictionary["inputValue"]),
              let result = numberValue(dictionary["result"]) else {
            return nil
        }
        return HistoryEntry(timestamp: timestamp,
                            expression: expression,
                            category: category,
                            inputValue: inputValue,
                            fromSymbol: fromSymbol,
                            toSymbol: toSymbol,
                            result: result,
                            exact: boolValue(dictionary["exact"]) ?? false)
    }

    /// One-line preview used by error messages and tests.
    public var summary: String {
        "\(Unit.trimNumber(result)) \(toSymbol)"
    }

    // MARK: Decode helpers

    /// Number extraction that works for Double, Int, and NSNumber payloads.
    static func numberValue(_ any: Any?) -> Double? {
        if let double = any as? Double { return double }
        if let number = any as? NSNumber { return number.doubleValue }
        if let integer = any as? Int { return Double(integer) }
        return nil
    }

    /// Boolean extraction with the same NSNumber tolerance.
    static func boolValue(_ any: Any?) -> Bool? {
        if let bool = any as? Bool { return bool }
        if let number = any as? NSNumber { return number.boolValue }
        return nil
    }
}

// MARK: - HistoryStore

/// Reads, appends to, clears, and describes the history file.
public final class HistoryStore {

    /// Directory holding the history file (default ~/.unitwise).
    public let directory: String
    /// Full path of the history JSON file.
    public let filePath: String
    /// Maximum entries kept; older entries are dropped on append.
    public let limit: Int

    /// Creates a store. `directory` defaults to ~/.unitwise; tests pass a
    /// temporary directory instead. The directory is created lazily on the
    /// first append.
    public init(directory: String? = nil, limit: Int = 200) {
        let base = directory ?? NSHomeDirectory() + "/.unitwise"
        self.directory = base
        self.filePath = base + "/history.json"
        self.limit = max(1, limit)
    }

    // MARK: Reading

    /// Loads all entries, oldest first. Missing/corrupt data → empty list.
    public func load() -> [HistoryEntry] {
        guard let data = FileManager.default.contents(atPath: filePath),
              !data.isEmpty else {
            return []
        }
        guard let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let list = object as? [[String: Any]] else {
            return []
        }
        return list.compactMap { HistoryEntry.decode($0) }
    }

    /// Most recent `count` entries (default 20), newest first.
    public func recent(_ count: Int? = nil) -> [HistoryEntry] {
        let entries = load()
        let take = count ?? 20
        guard take > 0 else { return [] }
        return Array(entries.suffix(take).reversed())
    }

    /// One-line status: entry count, file path, and file size.
    public func describe() -> String {
        let entries = load()
        var size = 0
        if let attributes = try? FileManager.default.attributesOfItem(atPath: filePath),
           let fileSize = HistoryEntry.numberValue(attributes[.size]) {
            size = Int(fileSize)
        }
        let plural = entries.count == 1 ? "entry" : "entries"
        return "history: \(entries.count) \(plural) at \(filePath) "
            + "(\(DataSizeBase.humanBytes(Double(size))))"
    }

    // MARK: Writing

    /// Appends one entry, trims to `limit`, and rewrites the file atomically.
    /// Creates the directory on first use.
    public func append(_ entry: HistoryEntry) throws {
        try ensureDirectory()
        var entries = load()
        entries.append(entry)
        if entries.count > limit {
            entries = Array(entries.suffix(limit))
        }
        let objects = entries.map { $0.dictionary }
        guard JSONSerialization.isValidJSONObject(objects) else {
            throw UnitWiseError.io("history payload is not valid JSON")
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: objects,
                                                  options: [.sortedKeys])
            try data.write(to: URL(fileURLWithPath: filePath), options: .atomic)
        } catch {
            throw UnitWiseError.io("cannot write history: \(error.localizedDescription)")
        }
    }

    /// Deletes the history file; a missing file is a successful no-op.
    public func clear() throws {
        guard FileManager.default.fileExists(atPath: filePath) else { return }
        do {
            try FileManager.default.removeItem(atPath: filePath)
        } catch {
            throw UnitWiseError.io("cannot clear history: \(error.localizedDescription)")
        }
    }

    // MARK: Internals

    /// Creates `directory` (including intermediates) when absent.
    private func ensureDirectory() throws {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: directory, isDirectory: &isDirectory),
           isDirectory.boolValue {
            return
        }
        do {
            try FileManager.default.createDirectory(atPath: directory,
                                                    withIntermediateDirectories: true)
        } catch {
            throw UnitWiseError.io("cannot create '\(directory)': \(error.localizedDescription)")
        }
    }
}
