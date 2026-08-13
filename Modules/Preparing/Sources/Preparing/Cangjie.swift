import Foundation
import CommonExtensions

struct CangjieEntry: Hashable {
        let word: String
        let cangjie5: String
        let cangjie3: String
        let c5complex: Int
        let c3complex: Int
        let c5code: Int
        let c3code: Int
}

struct Cangjie {
        static func generate() -> [CangjieEntry] {
                let characters = LexiconConverter.jyutpingSourceLines.compactMap({ line -> String? in
                        guard let word = line.split(separator: "\t").first else { return nil }
                        guard word.count == 1 else { return nil }
                        return word.trimmingCharacters(in: .whitespaces)
                }).distinct()
                return characters.flatMap({ item -> [CangjieEntry] in
                        let cangjie5Values: [String] = match(cangjie5: item)
                        let cangjie3Values: [String] = match(cangjie3: item)
                        guard !(cangjie5Values.isEmpty && cangjie3Values.isEmpty) else { return [] }
                        var instances: [CangjieEntry] = []
                        let upperBound: Int = max(cangjie5Values.count, cangjie3Values.count)
                        for index in 0..<upperBound {
                                let cangjie5: String = cangjie5Values.fetch(index) ?? "X"
                                let cangjie3: String = cangjie3Values.fetch(index) ?? "X"
                                let c5code = cangjie5.serialCode
                                let c3code: Int = cangjie3.serialCode
                                let c5complex = cangjie5.count
                                let c3complex = cangjie3.count
                                let instance = CangjieEntry(word: item, cangjie5: cangjie5, cangjie3: cangjie3, c5complex: c5complex, c3complex: c3complex, c5code: c5code, c3code: c3code)
                                instances.append(instance)
                        }
                        return instances
                }).distinct()
        }

        static func match(cangjie5: String) -> [String] {
                return cangjie5Map[cangjie5] ?? []
        }
        static func match(cangjie3: String) -> [String] {
                return cangjie3Map[cangjie3] ?? []
        }

        private static let cangjie5Map: [String : [String]] = sourceMap(fileName: "cangjie5")
        private static let cangjie3Map: [String : [String]] = sourceMap(fileName: "cangjie3")

        private static func sourceMap(fileName: String) -> [String : [String]] {
                guard let url = Bundle.module.url(forResource: fileName, withExtension: "txt") else { fatalError("Failed to get URL of \(fileName).txt") }
                guard let sourceContent = try? String(contentsOf: url, encoding: .utf8) else { fatalError("Failed to read \(fileName).txt") }
                let sourceLines: [String] = sourceContent.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)
                return sourceLines.reduce(into: [String : [String]]()) { result, sourceLine in
                        let parts = sourceLine.split(separator: "\t").map({ String($0) })
                        guard parts.count == 2 else { return }
                        let word = parts[0]
                        let value = parts[1]
                        result[word, default: []].append(value)
                }
        }
}
