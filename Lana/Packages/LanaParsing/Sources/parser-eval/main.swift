import Foundation
import LanaCore
import LanaParsing

/// Corre el golden set contra el parser real y reporta accuracy agregada
/// (Docs/adr/0003-golden-set.md, `.claude/agents/parser-evaluator.md`). El
/// parser no es determinista — por eso cada caso corre varias veces y se
/// mide el agregado, nunca pass/fail por caso.
enum ParserEval {
    struct Thresholds: Decodable {
        let count: Double
        let amount: Double
        let category: Double
        let subcategory: Double
    }

    struct GoldenSetFile: Decodable {
        let version: Int
        let locale: String
        let thresholds: Thresholds
        let cases: [GoldenCase]
    }

    struct GoldenCase: Decodable {
        let id: Int
        let input: String
        let expected: [ExpectedTransaction]
    }

    struct ExpectedTransaction: Decodable {
        let amount: Double
        let category: String
        let subcategory: String?
        let payment: String?
    }

    struct Tally {
        var countCorrect = 0
        var countTotal = 0
        var amountHits = 0
        var categoryHits = 0
        var fieldTotal = 0
        var subcategoryHits = 0
        var subcategoryTotal = 0
        var failures: [String] = []
    }

    static let runsPerCase = 3
    private static let subcategoryMatcher = SubcategoryMatcher()

    static func run() async {
        guard CommandLine.arguments.count > 1 else {
            print("uso: parser-eval <ruta-al-golden-set.json>")
            exit(1)
        }

        let parser = FoundationModelsExpenseParsing()
        let availability = parser.availability
        guard availability == .available else {
            print("El modelo no está disponible (\(availability)).")
            print("Cualquier número que se reporte sería basura — no se corre nada.")
            exit(1)
        }

        let path = CommandLine.arguments[1]
        let url = URL(fileURLWithPath: path)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            print("No se pudo leer \(path): \(error)")
            exit(1)
        }

        let file: GoldenSetFile
        do {
            file = try JSONDecoder().decode(GoldenSetFile.self, from: data)
        } catch {
            print("No se pudo decodificar \(path): \(error)")
            exit(1)
        }

        var tally = Tally()

        for goldenCase in file.cases {
            for _ in 0 ..< runsPerCase {
                let results: [ParseResult]
                do {
                    results = try await parser.parse(goldenCase.input)
                } catch {
                    tally.failures.append("caso \(goldenCase.id): error al parsear — \(error)")
                    continue
                }
                score(goldenCase, results: results, into: &tally)
            }
        }

        report(file: file, tally: tally)
    }

    private static func score(_ goldenCase: GoldenCase, results: [ParseResult], into tally: inout Tally) {
        tally.countTotal += 1
        if results.count == goldenCase.expected.count {
            tally.countCorrect += 1
        }

        var remaining = results
        for expected in goldenCase.expected {
            tally.fieldTotal += 1
            guard let index = remaining.firstIndex(where: { matches($0.amount, expected.amount) }) else {
                let message = "caso \(goldenCase.id): esperaba monto \(expected.amount), no llegó en la respuesta"
                tally.failures.append(message)
                continue
            }
            tally.amountHits += 1
            let matched = remaining.remove(at: index)
            scoreCategory(goldenCase: goldenCase, matched: matched, expected: expected, into: &tally)
            scoreSubcategory(goldenCase: goldenCase, matched: matched, expected: expected, into: &tally)
        }
    }

    private static func scoreCategory(
        goldenCase: GoldenCase,
        matched: ParseResult,
        expected: ExpectedTransaction,
        into tally: inout Tally) {
        if matched.category == expected.category {
            tally.categoryHits += 1
        } else {
            let got = matched.category ?? "nil"
            tally.failures.append("caso \(goldenCase.id): categoría '\(got)' ≠ esperada '\(expected.category)'")
        }
    }

    private static func scoreSubcategory(
        goldenCase: GoldenCase,
        matched: ParseResult,
        expected: ExpectedTransaction,
        into tally: inout Tally) {
        guard let expectedSubcategory = expected.subcategory else { return }
        tally.subcategoryTotal += 1
        let resolved = subcategoryMatcher.resolve(matched.subcategory ?? "", existing: [expectedSubcategory])
        if resolved == expectedSubcategory {
            tally.subcategoryHits += 1
        } else {
            let got = matched.subcategory ?? "nil"
            let message = "caso \(goldenCase.id): subcategoría '\(got)' ≠ esperada '\(expectedSubcategory)'"
            tally.failures.append(message)
        }
    }

    private static func matches(_ money: Money?, _ expected: Double) -> Bool {
        guard let money else { return false }
        // Comparación con tolerancia: `expected` viene de JSON (Double) y
        // `money.amount` de AmountValidator (Decimal exacto) — es una
        // comparación de medición, no aritmética financiera.
        return abs((money.amount as NSDecimalNumber).doubleValue - expected) < 0.01
    }

    private static func report(file: GoldenSetFile, tally: Tally) {
        let countAccuracy = tally.countTotal == 0 ? 0 : Double(tally.countCorrect) / Double(tally.countTotal)
        let amountAccuracy = tally.fieldTotal == 0 ? 0 : Double(tally.amountHits) / Double(tally.fieldTotal)
        let categoryAccuracy = tally.fieldTotal == 0 ? 0 : Double(tally.categoryHits) / Double(tally.fieldTotal)
        let subcategoryAccuracy = tally.subcategoryTotal == 0
            ? 0 : Double(tally.subcategoryHits) / Double(tally.subcategoryTotal)

        print("Accuracy del parser — \(file.cases.count) casos × \(runsPerCase) corridas, locale \(file.locale)")
        print("")
        print(line("Monto", amountAccuracy, file.thresholds.amount, tally.amountHits, tally.fieldTotal))
        print(line("Categoría", categoryAccuracy, file.thresholds.category, tally.categoryHits, tally.fieldTotal))
        print(line(
            "Subcategoría", subcategoryAccuracy, file.thresholds.subcategory,
            tally.subcategoryHits, tally.subcategoryTotal))
        print(line("Conteo", countAccuracy, file.thresholds.count, tally.countCorrect, tally.countTotal))

        if !tally.failures.isEmpty {
            print("")
            print("Fallos (\(tally.failures.count)):")
            for failure in tally.failures {
                print("- \(failure)")
            }
        }
    }

    private static func line(
        _ label: String,
        _ accuracy: Double,
        _ threshold: Double,
        _ hits: Int,
        _ total: Int) -> String {
        let percent = String(format: "%5.1f%%", accuracy * 100)
        let mark = accuracy >= threshold ? "✓" : "✗"
        let paddedLabel = label.padding(toLength: 12, withPad: " ", startingAt: 0)
        return "\(paddedLabel) \(percent)  (\(hits)/\(total))  \(mark) umbral \(Int(threshold * 100))%"
    }
}

await ParserEval.run()
