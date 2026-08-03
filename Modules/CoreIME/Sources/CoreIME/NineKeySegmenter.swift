import Foundation
import SQLite3
import os.log
import CommonExtensions

private extension Combo {
        static func matchCombo(for digit: Int) -> Combo? {
                return Self.allCases.first(where: { $0.digit == digit })
        }
}
private extension Int {
        var matchedCombos: [Combo] {
                var number = self
                var codes: [Int] = []
                while number > 0 {
                        codes.append(number % 10)
                        number /= 10
                }
                return codes.reversed().compactMap(Combo.matchCombo(for:))
        }
}

/// A Jyutping syllable represented by its 9-key alias and origin sequences.
public struct NineKeySyllable: Hashable, Comparable, Sendable {

        init(aliasCode: Int, originCode: Int, serialAliasCode: Int, serialOriginCode: Int) {
                self.aliasCode = aliasCode
                self.originCode = originCode
                self.alias = aliasCode.matchedCombos
                self.origin = originCode.matchedCombos
                self.serialAliasCode = serialAliasCode
                self.serialOriginCode = serialOriginCode
                self.serialAlias = serialAliasCode.matchedInputKeys
                self.serialOrigin = serialOriginCode.matchedInputKeys
        }

        let aliasCode: Int
        let originCode: Int
        let alias: Array<Combo>
        let origin: Array<Combo>

        let serialAliasCode: Int
        let serialOriginCode: Int
        let serialAlias: Array<VirtualInputKey>
        let serialOrigin: Array<VirtualInputKey>

        public static func ==(lhs: NineKeySyllable, rhs: NineKeySyllable) -> Bool {
                return lhs.aliasCode == rhs.aliasCode && lhs.originCode == rhs.originCode
        }
        public func hash(into hasher: inout Hasher) {
                hasher.combine(aliasCode)
                hasher.combine(originCode)
        }
        public static func <(lhs: NineKeySyllable, rhs: NineKeySyllable) -> Bool {
                let aliasQuotient = lhs.aliasCode / rhs.aliasCode
                guard aliasQuotient == 0 else { return true }
                let originQuotient = lhs.originCode / rhs.originCode
                return originQuotient > 0
        }
}

extension NineKeySyllable {
        public var isRegular: Bool { aliasCode == originCode }
        public var isIrregular: Bool { aliasCode != originCode }
}

public typealias NineKeyScheme = Array<NineKeySyllable>
public typealias NineKeySegmentation = Array<NineKeyScheme>

extension RandomAccessCollection where Element == NineKeySyllable {

        /// Count of all alias combos
        public var length: Int {
                return map(\.alias.count).reduce(0, +)
        }

        /// Conjoined digit of syllable origin lengths.
        ///
        /// For example: lengths of syllables “gwong dung dou” are `[5, 4, 3]`, which makes the `complexity` become `543`
        public var complexity: Int {
                return map(\.origin.count).decimalOverflowed()
        }

        /// Alias combos conjoined as a sequence
        public var aliasCombos: [Combo] {
                return flatMap(\.alias)
        }

        /// Origin combos conjoined as a sequence
        public var originCombos: [Combo] {
                return flatMap(\.origin)
        }

        /// Serial origin keys conjoined as a sequence
        public var serialOriginKeys: [VirtualInputKey] {
                return flatMap(\.serialOrigin)
        }
}

/// Segments 9-key input into possible Jyutping syllable schemes.
public struct NineKeySegmenter {

        private static let logger = Logger(subsystem: "org.jyutping.Jyutping.CoreIME", category: "NineKeySegmenter")
        static func prepare() {
                if syllableCodeMap.isEmpty {
                        logger.warning("NineKeySyllable Dictionary is Empty")
                }
        }
        private static let syllableCodeMap: Dictionary<Int, NineKeySyllable> = {
                let command: String = "SELECT alias_code, origin_code, alias_9key_code, origin_9key_code FROM syllable_9key_table ORDER BY rowid;"
                var statement: OpaquePointer? = nil
                defer { sqlite3_finalize(statement) }
                guard sqlite3_prepare_v2(Engine.database, command, -1, &statement, nil) == SQLITE_OK else { return [:] }
                var dict: [Int: NineKeySyllable] = [:]
                dict.reserveCapacity(700)
                while sqlite3_step(statement) == SQLITE_ROW {
                        let serialAliasCode = Int(sqlite3_column_int64(statement, 0))
                        let serialOriginCode = Int(sqlite3_column_int64(statement, 1))
                        let nineKeyAliasCode = Int(sqlite3_column_int64(statement, 2))
                        let nineKeyOriginCode = Int(sqlite3_column_int64(statement, 3))
                        let syllable = NineKeySyllable(aliasCode: nineKeyAliasCode, originCode: nineKeyOriginCode, serialAliasCode: serialAliasCode, serialOriginCode: serialOriginCode)
                        if let stored = dict[nineKeyAliasCode] {
                                if stored.isIrregular && syllable.isRegular {
                                        dict[nineKeyAliasCode] = syllable
                                }
                        } else {
                                dict[nineKeyAliasCode] = syllable
                        }
                }
                return dict
        }()
        private static func lookup(by code: Int) -> NineKeySyllable? {
                return syllableCodeMap[code]
        }

        private static let maxSyllableComboCount: Int = 6

        private struct SplitEdge {
                let syllable: NineKeySyllable
                let endIndex: Int
        }
        private struct SplitNode {
                let syllable: NineKeySyllable
                let previousIndex: Int?
                let length: Int
        }
        private static func splitEdges(for combos: [Combo]) -> [[SplitEdge]] {
                let inputLength = combos.count
                var edges = Array(repeating: Array<SplitEdge>(), count: inputLength)
                for startIndex in 0..<inputLength {
                        var code: Int = 0
                        let endIndexLimit = min(inputLength, startIndex + maxSyllableComboCount)
                        for endIndex in startIndex..<endIndexLimit {
                                code = code * 10 + combos[endIndex].digit
                                guard let syllable = lookup(by: code) else { continue }
                                edges[startIndex].append(SplitEdge(syllable: syllable, endIndex: endIndex + 1))
                        }
                }
                return edges
        }
        private static func scheme(at nodeIndex: Int, in nodes: [SplitNode]) -> NineKeyScheme {
                var syllables: NineKeyScheme = []
                syllables.reserveCapacity(nodes[nodeIndex].length)
                var currentIndex: Int? = nodeIndex
                while let index = currentIndex {
                        let node = nodes[index]
                        syllables.append(node.syllable)
                        currentIndex = node.previousIndex
                }
                syllables.reverse()
                return syllables
        }
        private static func split(_ combos: [Combo]) -> NineKeySegmentation {
                let inputLength = combos.count
                guard inputLength > 0 else { return [] }
                let edges = splitEdges(for: combos)
                guard (edges.first?.isNotEmpty ?? false) else { return [] }
                var nodes: [SplitNode] = []
                var nodeIndicesByLength = Array(repeating: Array<Int>(), count: inputLength + 1)
                for edge in edges[0] {
                        let node = SplitNode(syllable: edge.syllable, previousIndex: nil, length: edge.endIndex)
                        nodes.append(node)
                        nodeIndicesByLength[node.length].append(nodes.endIndex - 1)
                }
                var levelStartIndex: Int = 0
                var levelEndIndex: Int = nodes.count
                while levelStartIndex < levelEndIndex {
                        let nextLevelStartIndex = levelEndIndex
                        for nodeIndex in levelStartIndex..<levelEndIndex {
                                let node = nodes[nodeIndex]
                                guard node.length < inputLength else { continue }
                                for edge in edges[node.length] {
                                        let nextNode = SplitNode(syllable: edge.syllable, previousIndex: nodeIndex, length: edge.endIndex)
                                        nodes.append(nextNode)
                                        nodeIndicesByLength[nextNode.length].append(nodes.endIndex - 1)
                                }
                        }
                        levelStartIndex = nextLevelStartIndex
                        levelEndIndex = nodes.count
                }
                var schemes: NineKeySegmentation = []
                schemes.reserveCapacity(nodes.count)
                for length in (1...inputLength).reversed() {
                        for nodeIndex in nodeIndicesByLength[length] {
                                schemes.append(scheme(at: nodeIndex, in: nodes))
                        }
                }
                return schemes
        }

        /// Returns possible syllable schemes ordered by consumed input length, then syllable count.
        public static func segment(_ combos: [Combo]) -> NineKeySegmentation {
                return split(combos)
        }
}
