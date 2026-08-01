import Foundation
import SQLite3
import CommonExtensions
import os.log

private extension Int {
        var pinyinMatchedCombos: [Combo] {
                var number = self
                var combos: [Combo] = []
                while number > 0 {
                        if let combo = Combo(rawValue: number % 10) {
                                combos.append(combo)
                        }
                        number /= 10
                }
                return combos.reversed()
        }
}

public struct PinyinNineKeySyllable: Hashable, Sendable {

        init(code: Int) {
                self.code = code
                self.combos = code.pinyinMatchedCombos
        }

        let code: Int
        let combos: Array<Combo>
}

public typealias PinyinNineKeyScheme = Array<PinyinNineKeySyllable>
public typealias PinyinNineKeySegmentation = Array<PinyinNineKeyScheme>

extension RandomAccessCollection where Element == PinyinNineKeySyllable {

        /// Count of all input combos.
        public var length: Int {
                return map(\.combos.count).summation
        }

        /// Conjoined digit of syllable lengths.
        ///
        /// For example: lengths of syllables “xi an shi” are `[2, 2, 3]`, which makes the `complexity` become `223`.
        public var complexity: Int {
                return map(\.combos.count).decimalOverflowed()
        }

        /// Input combos conjoined as a sequence.
        public var combos: [Combo] {
                return flatMap(\.combos)
        }
}

public struct PinyinNineKeySegmenter {

        private static let logger = Logger(subsystem: "org.jyutping.Jyutping.CoreIME", category: "PinyinNineKeySegmenter")
        static func prepare() {
                if syllableCodeMap.isEmpty {
                        logger.warning("PinyinNineKeySyllable Dictionary is Empty")
                }
        }
        private static let syllableCodeMap: Dictionary<Int, PinyinNineKeySyllable> = {
                let command: String = "SELECT DISTINCT code_9key FROM syllable_pinyin_table ORDER BY code_9key;"
                var statement: OpaquePointer? = nil
                defer { sqlite3_finalize(statement) }
                guard sqlite3_prepare_v2(Engine.database, command, -1, &statement, nil) == SQLITE_OK else { return [:] }
                var dict: [Int: PinyinNineKeySyllable] = [:]
                dict.reserveCapacity(500)
                while sqlite3_step(statement) == SQLITE_ROW {
                        let code = Int(sqlite3_column_int64(statement, 0))
                        dict[code] = PinyinNineKeySyllable(code: code)
                }
                return dict
        }()
        private static func lookup(by code: Int) -> PinyinNineKeySyllable? {
                return syllableCodeMap[code]
        }

        private static let maxSyllableComboCount: Int = 6

        private struct SplitEdge {
                let syllable: PinyinNineKeySyllable
                let endIndex: Int
        }
        private struct SplitNode {
                let syllable: PinyinNineKeySyllable
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
        private static func scheme(at nodeIndex: Int, in nodes: [SplitNode]) -> PinyinNineKeyScheme {
                var syllables: PinyinNineKeyScheme = []
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
        private static func split(_ combos: [Combo]) -> PinyinNineKeySegmentation {
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
                var schemes: PinyinNineKeySegmentation = []
                schemes.reserveCapacity(nodes.count)
                for length in (1...inputLength).reversed() {
                        for nodeIndex in nodeIndicesByLength[length] {
                                schemes.append(scheme(at: nodeIndex, in: nodes))
                        }
                }
                return schemes
        }

        public static func segment<T: RandomAccessCollection<Combo>>(_ combos: T) -> PinyinNineKeySegmentation {
                return split(Array(combos))
        }
}
