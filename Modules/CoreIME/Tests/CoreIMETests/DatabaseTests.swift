import Foundation
import SQLite3
import Testing

@Suite("Packaged databases")
struct DatabaseTests {

        @Test("mobile database contains nine-key schema")
        func mobileSchema() {
                let schema = schema(at: mobileDatabaseURL)

                #expect(schema.contains("syllable_9key_table"))
                #expect(schema.contains("anchors_9key"))
                #expect(schema.contains("spell_9key"))
                #expect(schema.contains("code_9key"))
        }

        @Test("desktop database excludes nine-key schema")
        func desktopSchema() {
                let schema = schema(at: desktopDatabaseURL)

                #expect(schema.contains("9key") == false)
        }

        private func schema(at url: URL) -> String {
                var database: OpaquePointer? = nil
                let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
                guard sqlite3_open_v2(url.path, &database, flags, nil) == SQLITE_OK else { return "" }
                defer { sqlite3_close_v2(database) }
                let command = "SELECT sql FROM sqlite_schema WHERE sql IS NOT NULL ORDER BY name;"
                var statement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { return "" }
                defer { sqlite3_finalize(statement) }
                var statements: [String] = []
                while sqlite3_step(statement) == SQLITE_ROW {
                        guard let text = sqlite3_column_text(statement, 0) else { continue }
                        statements.append(String(cString: text))
                }
                return statements.joined(separator: "\n")
        }
}
