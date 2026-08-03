import Foundation
import SQLite3
import CommonExtensions

extension Engine {
        public static func searchPlainTexts<T: RandomAccessCollection<VirtualInputKey>>(for keys: T) -> [Lexicon] {
                let spell = keys.conjoinedCode.toInt64()
                let letterCount = keys.count.toInt64()
                let command: String = "SELECT word FROM plain_text_table WHERE spell = ? AND letter_count = ? ORDER BY rowid;"
                var statement: OpaquePointer? = nil
                defer { sqlite3_finalize(statement) }
                guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { return [] }
                guard sqlite3_bind_int64(statement, 1, spell) == SQLITE_OK else { return [] }
                guard sqlite3_bind_int64(statement, 2, letterCount) == SQLITE_OK else { return [] }
                var entries: [String] = []
                while sqlite3_step(statement) == SQLITE_ROW {
                        guard let word = sqlite3_column_text(statement, 0) else { continue }
                        entries.append(String(cString: word))
                }
                guard entries.isNotEmpty else { return [] }
                let input: String = keys.map(\.text).joined()
                return entries.map({ Lexicon(input: input, text: $0) })
        }
        public static func queryPlainTexts<T: RandomAccessCollection<Combo>>(for combos: T) -> [Lexicon] {
                let code = combos.map(\.digit).decimalOverflowed().toInt64()
                let letterCount = combos.count.toInt64()
                let command: String = "SELECT input, word FROM plain_text_table WHERE spell_9key = ? AND letter_count = ? ORDER BY rowid;"
                var statement: OpaquePointer? = nil
                defer { sqlite3_finalize(statement) }
                guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { return [] }
                guard sqlite3_bind_int64(statement, 1, code) == SQLITE_OK else { return [] }
                guard sqlite3_bind_int64(statement, 2, letterCount) == SQLITE_OK else { return [] }
                var entries: [Lexicon] = []
                while sqlite3_step(statement) == SQLITE_ROW {
                        guard let input = sqlite3_column_text(statement, 0) else { continue }
                        guard let word = sqlite3_column_text(statement, 1) else { continue }
                        let instance = Lexicon(input: String(cString: input), text: String(cString: word))
                        entries.append(instance)
                }
                return entries
        }
}
