//
//  SelfTest.swift
//  unitwise
//
//  Built-in sanity checks run by `unitwise selftest` and re-used by the
//  XCTest suite. Every check goes through the same public pipeline a user
//  command would take — parse → evaluate → compare — so a green selftest
//  means the whole stack (registry, resolver, parser, engine) agrees.
//
//  The checks are grouped to mirror the tricky corners of the codebase:
//    * registry: ten categories build and validate,
//    * temperature: affine offsets cancel correctly both directions,
//    * datasize: decimal kB vs binary KiB, plus the --base2 token remap,
//    * length/volume/speed/time: spot anchors from the exact constants,
//    * energy/pressure/area: the newest categories' agreed factors,
//    * parser: plural stripping, µ normalization, case-insensitivity,
//    * formatter: significant-figure rendering is deterministic.
//
//  Failure policy: runAll() never throws and never crashes — a broken
//  registry degrades to a single failing check instead of a trap, so
//  `unitwise selftest` can always report what it could and could not
//  verify. Exit code 0 means every check passed.
//

import Foundation

// MARK: - SelfTest

/// Named checks with pass/fail outcomes; nothing here throws.
public enum SelfTest {

    /// One named check with its outcome.
    public struct Check: Equatable {
        public let name: String
        public let passed: Bool
        public let detail: String
    }

    /// Relative tolerance for floating-point anchors (1e-9 matches the
    /// round-trip tolerance used by ConversionEngine).
    static func approx(_ lhs: Double, _ rhs: Double, tolerance: Double = 1e-9) -> Bool {
        guard lhs.isFinite, rhs.isFinite else { return false }
        if lhs == rhs { return true }
        return abs(lhs - rhs) <= tolerance * max(abs(lhs), abs(rhs))
    }

    /// Runs every check and returns them in a stable order.
    public static func runAll() -> [Check] {
        var checks: [Check] = []

        func add(_ name: String, _ condition: Bool, _ detail: String = "") {
            checks.append(Check(name: name,
                                passed: condition,
                                detail: condition ? "ok" : detail))
        }

        guard let resolver = try? UnitResolver(categories: CategoryRegistry.categories) else {
            return [Check(name: "registry builds",
                          passed: false,
                          detail: "UnitResolver init threw")]
        }
        add("registry builds", true)
        add("ten categories registered",
            CategoryRegistry.categories.count == 10,
            "count is \(CategoryRegistry.categories.count)")

        func evaluate(_ expression: String, base: DataSizeBase = .decimal) -> ConversionResult? {
            let remapped = base.remapExpression(expression)
            guard let request = try? ExpressionParser.parse(expression: remapped,
                                                            resolver: resolver) else {
                return nil
            }
            return try? ConversionEngine().evaluate(request)
        }

        func numericCheck(_ name: String,
                          _ expression: String,
                          expected: Double,
                          base: DataSizeBase = .decimal) {
            if let converted = evaluate(expression, base: base) {
                add(name, approx(converted.result, expected), "got \(converted.result)")
            } else {
                add(name, false, "expression failed to parse or evaluate")
            }
        }

        // Temperature offsets (affine scales).
        numericCheck("temperature: -40 °C → -40 °F", "-40 c to f", expected: -40)
        numericCheck("temperature: 0 °C → 273.15 K", "0 c to k", expected: 273.15)
        numericCheck("temperature: 100 °C → 212 °F", "100 c to f", expected: 212)

        // Binary vs decimal data sizes.
        numericCheck("datasize: 1 GiB → 1073741824 B", "1 gib to byte", expected: 1073741824)
        numericCheck("datasize: 3.5 MB → 3500 kB (decimal)", "3.5 mb to kb", expected: 3500)
        numericCheck("datasize: 3.5 MB → 3670.016 kB (base2)",
                     "3.5 mb to kb", expected: 3670.016, base: .binary)

        // Spot anchors from the exact constants of the older categories.
        numericCheck("length: 1 mi → 1609.344 m", "1 mi to m", expected: 1609.344)
        numericCheck("length: 1 in → 2.54 cm", "1 in to cm", expected: 2.54)
        numericCheck("mass: 1 lb → 453.59237 g", "1 lb to g", expected: 453.59237)
        numericCheck("volume: 1 gal → 3.785411784 L", "1 gal to l", expected: 3.785411784)
        numericCheck("speed: 100 km/h → 27.77… m/s",
                     "100 kmh to mps", expected: 1000.0 / 36.0)
        numericCheck("time: 1 yr → 31557600 s", "1 yr to s", expected: 31557600)

        // New categories anchor on their agreed constants.
        numericCheck("energy: 1 kcal → 4184 J", "1 kcal to j", expected: 4184)
        numericCheck("energy: 1 kWh → 3.6e6 J", "1 kwh to j", expected: 3.6e6)
        numericCheck("pressure: 1 atm → 101325 Pa", "1 atm to pa", expected: 101325)
        numericCheck("pressure: 1 psi → 6894.757… Pa",
                     "1 psi to pa", expected: PressureCategory.pascalsPerPSI)
        numericCheck("area: 1 acre → 4046.8564224 m²",
                     "1 acre to m2", expected: AreaCategory.squareMetersPerAcre)

        // Parser behaviors.
        let pluralCandidates = resolver.candidates(for: "kms")
        add("plural alias 'kms' resolves to kilometer",
            pluralCandidates.first?.id == "kilometer",
            "resolved \(pluralCandidates.map { $0.qualifiedName })")
        let remapped = DataSizeBase.binary.remapExpression("3.5 MB to kB")
        add("base2 token remap rewrites MB → MiB", remapped == "3.5 MiB to kB",
            "got '\(remapped)'")
        add("µ normalization maps µs → us",
            ExpressionParser.normalizeToken("µs") == "us",
            "got '\(ExpressionParser.normalizeToken("µs"))'")

        if let converted = evaluate("5 KM TO MI") {
            add("case-insensitive expression parses", true)
            add("round-trip stability flag set", converted.exact,
                "roundTrip \(converted.roundTrip)")
        } else {
            add("case-insensitive expression parses", false,
                "'5 KM TO MI' failed to evaluate")
            add("round-trip stability flag set", false, "no result to inspect")
        }

        // Formatter determinism.
        add("formatter: six significant figures",
            NumberText.significant(3.1068559611866697, figures: 6) == "3.10686",
            "got '\(NumberText.significant(3.1068559611866697, figures: 6))'")

        return checks
    }

    /// Convenience for CI scripts: true when every check in `checks`
    /// passed (defaults to a fresh full run when omitted).
    public static func allPassed(_ checks: [Check]? = nil) -> Bool {
        (checks ?? runAll()).allSatisfy { $0.passed }
    }
}
