import Foundation
import CommonExtensions

struct PlainText: Hashable {

        let input: String
        let word: String

        /// Length of the `input`
        let letterCount: Int

        let spell: Int
        let nineKeySpell: Int

        static func == (lhs: PlainText, rhs: PlainText) -> Bool {
                return lhs.input == rhs.input && lhs.word == rhs.word
        }

        func hash(into hasher: inout Hasher) {
                hasher.combine(input)
                hasher.combine(word)
        }
}

extension PlainText {
        static func convert() -> [PlainText] {
                guard let url = Bundle.module.url(forResource: "text", withExtension: "txt") else { fatalError("Failed to get the URL of text.txt") }
                guard let sourceContent = try? String(contentsOf: url, encoding: .utf8) else { fatalError("Failed to read text.txt") }
                let sourceLines: [String] = sourceContent
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .components(separatedBy: .newlines)
                        .map({ $0.trimmingCharacters(in: .whitespaces) })
                        .filter({ $0.isNotEmpty && $0.hasPrefix(String.numberSign).negative })
                        .distinct()
                return sourceLines.compactMap({ line -> PlainText? in
                        let parts = line.split(separator: String.tab).map({ $0.trimmingCharacters(in: .whitespaces) })
                        guard parts.count >= 2 else { fatalError("Bad line format in text.txt:  \(line)") }
                        let input = parts[0]
                        let word = parts[1]
                        let letterCount = input.count
                        let spell = input.serialCode
                        let nineKeySpell = input.keypadCode
                        return PlainText(input: input, word: word, letterCount: letterCount, spell: spell, nineKeySpell: nineKeySpell)
                }).distinct()
        }
}
