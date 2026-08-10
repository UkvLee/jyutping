import Foundation
import SQLite3
import CommonExtensions

public struct NineKeyEngine {

        private static let nineKeyAnchorsQuery: String = "SELECT rowid, word, romanization FROM lexicon_core WHERE anchors_9key = ? AND char_count = ? ORDER BY rowid LIMIT ?;"
        static func prepareNineKeyAnchorsStatement() -> OpaquePointer? {
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(Engine.database, nineKeyAnchorsQuery, -1, &statement, nil) == SQLITE_OK else { return nil }
                return statement
        }

        private static let nineKeySpellQuery: String = "SELECT rowid, word, romanization FROM lexicon_core WHERE spell_9key = ? AND complexity = ? ORDER BY rowid LIMIT ?;"
        static func prepareNineKeySpellStatement() -> OpaquePointer? {
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(Engine.database, nineKeySpellQuery, -1, &statement, nil) == SQLITE_OK else { return nil }
                return statement
        }

        private static let serialQuery: String = "SELECT rowid, word, romanization FROM lexicon_core WHERE spell = ? AND complexity = ? ORDER BY rowid LIMIT ?;"
        static func prepareSerialStatement() -> OpaquePointer? {
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(Engine.database, serialQuery, -1, &statement, nil) == SQLITE_OK else { return nil }
                return statement
        }

        public static func suggest<T: RandomAccessCollection<Combo>>(combos: T, segmentation: NineKeySegmentation) async -> [Lexicon] {
                lazy var anchorsStatement = prepareNineKeyAnchorsStatement()
                lazy var spellStatement = prepareNineKeySpellStatement()
                defer {
                        sqlite3_finalize(anchorsStatement)
                        sqlite3_finalize(spellStatement)
                }
                let shouldProcessSlices: Bool = (segmentation.first?.first?.alias.count ?? 0) == 0
                if shouldProcessSlices {
                        return processSlices(combos: combos, anchorsStatement: anchorsStatement, spellStatement: spellStatement)
                } else {
                        return search(combos: combos, segmentation: segmentation, anchorsStatement: anchorsStatement, spellStatement: spellStatement)
                }
        }

        private static func processSlices<T: RandomAccessCollection<Combo>>(combos: T, limit: Int64? = nil, anchorsStatement: OpaquePointer?, spellStatement: OpaquePointer?) -> [Lexicon] {
                guard combos.isNotEmpty else { return [] }
                return (1...combos.count).reversed()
                        .flatMap({ number -> [Lexicon] in
                                guard Task.isCancelled.negative else { return [] }
                                guard number <= Engine.MAX_CHAR_COUNT else { return [] }
                                return anchorsMatch(combos: combos.prefix(number), limit: limit, statement: anchorsStatement)
                        })
        }

        private static func search<T: RandomAccessCollection<Combo>>(combos: T, segmentation: NineKeySegmentation, limit: Int64? = nil, anchorsStatement: OpaquePointer?, spellStatement: OpaquePointer?) -> [Lexicon] {
                guard Task.isCancelled.negative else { return [] }
                let inputLength: Int = combos.count
                guard inputLength > 1 else { return anchorsMatch(combos: combos, limit: limit, statement: anchorsStatement) }
                let anchorsMatched = anchorsMatch(combos: combos, limit: limit, statement: anchorsStatement)
                let queried = query(inputLength: inputLength, segmentation: segmentation, limit: limit, statement: spellStatement)
                let fetched: [Lexicon] = {
                        let idealQueried = queried.filter({ $0.inputCount == inputLength }).sorted(by: { $0.number < $1.number }).distinct()
                        let notIdealQueried = queried.filter({ $0.inputCount < inputLength }).sorted().distinct()
                        let extra = idealQueried.isNotEmpty ? [] : ExtraEntry.nineKeySearch(combos: combos)
                        return (idealQueried + extra + anchorsMatched.prefix(4) + notIdealQueried).distinct()
                }()
                guard let firstInputCount = fetched.first?.inputCount else {
                        return processSlices(combos: combos, limit: limit, anchorsStatement: anchorsStatement, spellStatement: spellStatement)
                }
                guard firstInputCount < inputLength else { return fetched }
                let tailCombos = Array(combos.dropFirst(firstInputCount))
                let tailSegmentation = NineKeySegmenter.segment(tailCombos)
                let tailLexicons = search(combos: tailCombos, segmentation: tailSegmentation, limit: 20, anchorsStatement: anchorsStatement, spellStatement: spellStatement)
                guard tailLexicons.isNotEmpty, let head = fetched.first else { return fetched }
                let concatenated = tailLexicons.compactMap({ head + $0 }).sorted().prefix(1)
                return concatenated + fetched
        }

        private static func query(inputLength: Int, segmentation: NineKeySegmentation, limit: Int64? = nil, statement: OpaquePointer?) -> [Lexicon] {
                let idealSchemes = segmentation.filter({ $0.length == inputLength })
                if idealSchemes.isEmpty {
                        return segmentation.flatMap({ perform(scheme: $0, limit: limit, statement: statement) })
                } else {
                        return idealSchemes.flatMap({ scheme -> [Lexicon] in
                                switch scheme.count {
                                case 0: return []
                                case 1: return perform(scheme: scheme, limit: limit, statement: statement)
                                default:
                                        return (1...scheme.count).reversed().flatMap({ perform(scheme: scheme.prefix($0), limit: limit, statement: statement) })
                                }
                        })
                }
        }
        private static func perform<T: RandomAccessCollection<NineKeySyllable>>(scheme: T, limit: Int64? = nil, statement: OpaquePointer?) -> [Lexicon] {
                guard Task.isCancelled.negative && (scheme.count <= Engine.MAX_CHAR_COUNT) else { return [] }
                let containsIrregular: Bool = scheme.contains(where: \.isIrregular)
                if containsIrregular {
                        let serialStatement = prepareSerialStatement()
                        defer { sqlite3_finalize(serialStatement) }
                        return serialMatch(keys: scheme.serialOriginKeys, complexity: scheme.complexity, limit: limit, statement: serialStatement)
                } else {
                        return spellMatch(combos: scheme.originCombos, complexity: scheme.complexity, limit: limit, statement: statement)
                }
        }
}

private extension NineKeyEngine {
        static func anchorsMatch<T: RandomAccessCollection<Combo>>(combos: T, limit: Int64? = nil, statement: OpaquePointer?) -> [Lexicon] {
                sqlite3_reset(statement)
                let charCount: Int64 = combos.count.toInt64()
                guard charCount <= Engine.MAX_CHAR_COUNT else { return [] }
                let anchorsCode: Int64 = combos.decimalCombinedCode.toInt64()
                let limit: Int64 = limit ?? 100
                sqlite3_bind_int64(statement, 1, anchorsCode)
                sqlite3_bind_int64(statement, 2, charCount)
                sqlite3_bind_int64(statement, 3, limit)
                var items: [Lexicon] = []
                while sqlite3_step(statement) == SQLITE_ROW {
                        let number: Int = Int(sqlite3_column_int64(statement, 0))
                        let word: String = String(cString: sqlite3_column_text(statement, 1))
                        let romanization: String = String(cString: sqlite3_column_text(statement, 2))
                        let anchors = romanization.split(separator: Character.space).compactMap(\.first)
                        let anchorText = String(anchors)
                        let instance = Lexicon(text: word, romanization: romanization, input: anchorText, mark: anchorText, number: number)
                        items.append(instance)
                }
                return items
        }
        static func spellMatch<T: RandomAccessCollection<Combo>>(combos: T, complexity: Int, input: String? = nil, mark: String? = nil, limit: Int64? = nil, statement: OpaquePointer?) -> [Lexicon] {
                sqlite3_reset(statement)
                let code: Int64 = combos.decimalCombinedCode.toInt64()
                let complexity: Int64 = complexity.toInt64()
                let limit: Int64 = limit ?? -1
                sqlite3_bind_int64(statement, 1, code)
                sqlite3_bind_int64(statement, 2, complexity)
                sqlite3_bind_int64(statement, 3, limit)
                var items: [Lexicon] = []
                while sqlite3_step(statement) == SQLITE_ROW {
                        let number: Int = Int(sqlite3_column_int64(statement, 0))
                        let word: String = String(cString: sqlite3_column_text(statement, 1))
                        let romanization: String = String(cString: sqlite3_column_text(statement, 2))
                        let mark: String = mark ?? romanization.strippedTones()
                        let input: String = input ?? mark.strippedSpaces()
                        let instance = Lexicon(text: word, romanization: romanization, input: input, mark: mark, number: number)
                        items.append(instance)
                }
                return items
        }
        static func serialMatch<T: RandomAccessCollection<VirtualInputKey>>(keys: T, complexity: Int, input: String? = nil, mark: String? = nil, limit: Int64? = nil, statement: OpaquePointer?) -> [Lexicon] {
                sqlite3_reset(statement)
                let spell: Int64 = keys.conjoinedCode.toInt64()
                let complexity: Int64 = complexity.toInt64()
                let limit: Int64 = limit ?? -1
                sqlite3_bind_int64(statement, 1, spell)
                sqlite3_bind_int64(statement, 2, complexity)
                sqlite3_bind_int64(statement, 3, limit)
                var items: [Lexicon] = []
                while sqlite3_step(statement) == SQLITE_ROW {
                        let number: Int = Int(sqlite3_column_int64(statement, 0))
                        let word: String = String(cString: sqlite3_column_text(statement, 1))
                        let romanization: String = String(cString: sqlite3_column_text(statement, 2))
                        let mark: String = mark ?? romanization.strippedTones()
                        let input: String = input ?? mark.strippedSpaces()
                        let instance = Lexicon(text: word, romanization: romanization, input: input, mark: mark, number: number)
                        items.append(instance)
                }
                return items
        }
}
