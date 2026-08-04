import Foundation
import SQLite3

struct AppDataPreparer {
        nonisolated(unsafe) private static let database: OpaquePointer? = {
                var db: OpaquePointer? = nil
                guard sqlite3_open_v2(":memory:", &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else { return nil }
                return db
        }()
        static func prepare() async {
                await withTaskGroup(of: Void.self) { group in
                        group.addTask { await prepareJyutpingTable() }
                        group.addTask { await prepareCollocationTable() }
                        group.addTask { await prepareDictionaryTable() }
                        group.addTask { await prepareYingWaaTable() }
                        group.addTask { await prepareChoHokTable() }
                        group.addTask { await prepareFanWanTable() }
                        group.addTask { await prepareGwongWanTable() }
                        group.addTask { await prepareDefinitionTable() }
                        await group.waitForAll()
                }
                createIndexes()
                backupInMemoryDatabase()
                sqlite3_close_v2(database)
        }
        private static func backupInMemoryDatabase() {
                let path: String = "../AppDataSource/Sources/AppDataSource/Resources/app.sqlite3"
                if FileManager.default.fileExists(atPath: path) {
                        try? FileManager.default.removeItem(atPath: path)
                }
                var destination: OpaquePointer? = nil
                defer { sqlite3_close_v2(destination) }
                guard sqlite3_open_v2(path, &destination, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK else { return }
                let backup = sqlite3_backup_init(destination, "main", database, "main")
                guard sqlite3_backup_step(backup, -1) == SQLITE_DONE else { return }
                guard sqlite3_backup_finish(backup) == SQLITE_OK else { return }
                let commands: [String] = [
                        "PRAGMA page_size = 16384;",
                        "PRAGMA journal_mode = DELETE;",
                        "VACUUM;",
                        "ANALYZE;",
                ]
                for command in commands {
                        var statement: OpaquePointer?
                        sqlite3_prepare_v2(destination, command, -1, &statement, nil)
                        sqlite3_step(statement)
                        sqlite3_finalize(statement)
                }
        }
}
private extension AppDataPreparer {
        static func createIndexes() {
                let commands: [String] = [
                        "CREATE INDEX ix_jyutping_word ON jyutping_table (word);",
                        "CREATE INDEX ix_jyutping_romanization ON jyutping_table (romanization);",

                        "CREATE INDEX ix_collocation_word_romanization ON collocation_table (word, romanization);",

                        "CREATE INDEX ix_dictionary_word_romanization ON dictionary_table (word, romanization);",

                        "CREATE INDEX ix_yingwaa_code ON yingwaa_table(code);",
                        "CREATE INDEX ix_yingwaa_romanization ON yingwaa_table(romanization);",

                        "CREATE INDEX ix_chohok_code ON chohok_table(code);",
                        "CREATE INDEX ix_chohok_romanization ON chohok_table(romanization);",

                        "CREATE INDEX ix_fanwan_code ON fanwan_table(code);",
                        "CREATE INDEX ix_fanwan_romanization ON fanwan_table(romanization);",

                        "CREATE INDEX ix_gwongwan_code ON gwongwan_table(code);",
                ]
                for command in commands {
                        var statement: OpaquePointer? = nil
                        defer { sqlite3_finalize(statement) }
                        guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { return }
                        guard sqlite3_step(statement) == SQLITE_DONE else { return }
                }
        }
}
private extension AppDataPreparer {
        static func prepareJyutpingTable() async {
                let command: String = "CREATE TABLE jyutping_table (id INTEGER PRIMARY KEY AUTOINCREMENT, word TEXT NOT NULL, romanization TEXT NOT NULL);"
                var statement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { sqlite3_finalize(statement); return }
                guard sqlite3_step(statement) == SQLITE_DONE else { sqlite3_finalize(statement); return }
                sqlite3_finalize(statement)
                let tableName: String = "jyutping_table"
                let columns: String = "(word, romanization)"
                guard let url = Bundle.module.url(forResource: "jyutping", withExtension: "txt") else { return }
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
                let sourceLines: [String] = content.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)
                let valueBlocks = sourceLines.compactMap { sourceLine -> String? in
                        let parts = sourceLine.split(separator: "\t")
                        guard parts.count == 2 else { return nil }
                        let word = parts[0]
                        let romanization = parts[1]
                        return "('\(word)', '\(romanization)')"
                }
                let values: String = valueBlocks.joined(separator: ", ")
                insert(tableName: tableName, columns: columns, values: values)
        }
}
private extension AppDataPreparer {
        static func prepareCollocationTable() async {
                let command: String = "CREATE TABLE collocation_table (id INTEGER PRIMARY KEY AUTOINCREMENT, word TEXT NOT NULL, romanization TEXT NOT NULL, collocation TEXT NOT NULL, UNIQUE (word, romanization));"
                var statement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { sqlite3_finalize(statement); return }
                guard sqlite3_step(statement) == SQLITE_DONE else { sqlite3_finalize(statement); return }
                sqlite3_finalize(statement)
                let tableName: String = "collocation_table"
                let columns: String = "(word, romanization, collocation)"
                guard let url = Bundle.module.url(forResource: "collocation", withExtension: "txt") else { return }
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
                let sourceLines: [String] = content.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)
                let valueBlocks = sourceLines.compactMap { sourceLine -> String? in
                        let parts = sourceLine.split(separator: "\t")
                        guard parts.count == 3 else { return nil }
                        let word = parts[0]
                        let romanization = parts[1]
                        let collocation = parts[2]
                        return "('\(word)', '\(romanization)', '\(collocation)')"
                }
                let values: String = valueBlocks.joined(separator: ", ")
                insert(tableName: tableName, columns: columns, values: values)
        }
}
private extension AppDataPreparer {
        static func prepareDictionaryTable() async {
                let command: String = "CREATE TABLE dictionary_table (id INTEGER PRIMARY KEY AUTOINCREMENT, word TEXT NOT NULL, romanization TEXT NOT NULL, description TEXT NOT NULL);"
                var statement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { sqlite3_finalize(statement); return }
                guard sqlite3_step(statement) == SQLITE_DONE else { sqlite3_finalize(statement); return }
                sqlite3_finalize(statement)
                let tableName: String = "dictionary_table"
                let columns: String = "(word, romanization, description)"
                guard let url = Bundle.module.url(forResource: "wordshk", withExtension: "txt") else { return }
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
                let sourceLines: [String] = content.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)
                let steps: Range<Int> = 0..<2000
                let stepSize: Int = sourceLines.count / 2000
                for step in steps {
                        let lower: Int = step * stepSize
                        let upper: Int = (step == 1999) ? sourceLines.count : ((step + 1) * stepSize)
                        let part = sourceLines[lower..<upper]
                        let valueBlocks = part.compactMap { sourceLine -> String? in
                                let parts = sourceLine.split(separator: "\t")
                                guard parts.count == 3 else { return nil }
                                let word = parts[0]
                                let romanization = parts[1]
                                let description = parts[2]
                                return "('\(word)', '\(romanization)', '\(description)')"
                        }
                        let values: String = valueBlocks.joined(separator: ", ")
                        insert(tableName: tableName, columns: columns, values: values)
                }
        }
}
private extension AppDataPreparer {
        static func prepareYingWaaTable() async {
                let command: String = "CREATE TABLE yingwaa_table(code INTEGER NOT NULL, word TEXT NOT NULL, romanization TEXT NOT NULL, pronunciation TEXT NOT NULL, note TEXT NOT NULL, interpretation TEXT NOT NULL);"
                var statement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { sqlite3_finalize(statement); return }
                guard sqlite3_step(statement) == SQLITE_DONE else { sqlite3_finalize(statement); return }
                sqlite3_finalize(statement)
                let tableName: String = "yingwaa_table"
                let columns: String = "(code, word, romanization, pronunciation, note, interpretation)"
                guard let url = Bundle.module.url(forResource: "yingwaa", withExtension: "txt") else { return }
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
                let sourceLines: [String] = content.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)
                let valueBlocks = sourceLines.compactMap { sourceLine -> String? in
                        let parts = sourceLine.split(separator: "\t")
                        guard parts.count == 5 else { return nil }
                        let word = parts[0]
                        guard let code = word.first?.decimalCode else { return nil }
                        let romanization = parts[1]
                        let pronunciation = parts[2]
                        let note = parts[3]
                        let interpretation = parts[4]
                        return "(\(code), '\(word)', '\(romanization)', '\(pronunciation)', '\(note)', '\(interpretation)')"
                }
                let values: String = valueBlocks.joined(separator: ", ")
                insert(tableName: tableName, columns: columns, values: values)
        }
        static func prepareChoHokTable() async {
                let command: String = "CREATE TABLE chohok_table(code INTEGER NOT NULL, word TEXT NOT NULL, romanization TEXT NOT NULL, phone TEXT NOT NULL, tone TEXT NOT NULL, faancit TEXT NOT NULL);"
                var statement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { sqlite3_finalize(statement); return }
                guard sqlite3_step(statement) == SQLITE_DONE else { sqlite3_finalize(statement); return }
                sqlite3_finalize(statement)
                let tableName: String = "chohok_table"
                let columns: String = "(code, word, romanization, phone, tone, faancit)"
                guard let url = Bundle.module.url(forResource: "chohok", withExtension: "txt") else { return }
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
                let sourceLines: [String] = content.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)
                let valueBlocks = sourceLines.compactMap { sourceLine -> String? in
                        let parts = sourceLine.split(separator: "\t")
                        guard parts.count == 5 else { return nil }
                        let word = parts[0]
                        guard let code = word.first?.decimalCode else { return nil }
                        let romanization = parts[1]
                        let phone = parts[2]
                        let tone = parts[3]
                        let faancit = parts[4]
                        return "(\(code), '\(word)', '\(romanization)', '\(phone)', '\(tone)', '\(faancit)')"
                }
                let values: String = valueBlocks.joined(separator: ", ")
                insert(tableName: tableName, columns: columns, values: values)
        }
        static func prepareFanWanTable() async {
                let command: String = "CREATE TABLE fanwan_table(code INTEGER NOT NULL, word TEXT NOT NULL, romanization TEXT NOT NULL, initial TEXT NOT NULL, final TEXT NOT NULL, yamyeung TEXT NOT NULL, tone TEXT NOT NULL, rhyme TEXT NOT NULL, interpretation TEXT NOT NULL);"
                var statement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { sqlite3_finalize(statement); return }
                guard sqlite3_step(statement) == SQLITE_DONE else { sqlite3_finalize(statement); return }
                sqlite3_finalize(statement)
                let tableName: String = "fanwan_table"
                let columns: String = "(code, word, romanization, initial, final, yamyeung, tone, rhyme, interpretation)"
                guard let url = Bundle.module.url(forResource: "fanwan", withExtension: "txt") else { return }
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
                let sourceLines: [String] = content.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)
                let valueBlocks = sourceLines.compactMap { sourceLine -> String? in
                        let parts = sourceLine.split(separator: "\t")
                        guard parts.count == 8 else { return nil }
                        let word = parts[0]
                        guard let code = word.first?.decimalCode else { return nil }
                        let romanization = parts[1]
                        let initial = parts[2]
                        let final = parts[3]
                        let yamyeung = parts[4]
                        let tone = parts[5]
                        let rhyme = parts[6]
                        let interpretation = parts[7]
                        return "(\(code), '\(word)', '\(romanization)', '\(initial)', '\(final)', '\(yamyeung)', '\(tone)', '\(rhyme)', '\(interpretation)')"
                }
                let values: String = valueBlocks.joined(separator: ", ")
                insert(tableName: tableName, columns: columns, values: values)
        }
        static func prepareGwongWanTable() async {
                let command: String = "CREATE TABLE gwongwan_table(code INTEGER NOT NULL, word TEXT NOT NULL, rhyme TEXT NOT NULL, subrhyme TEXT NOT NULL, subrhymeserial INTEGER NOT NULL, subrhymenumber INTEGER NOT NULL, upper TEXT NOT NULL, lower TEXT NOT NULL, initial TEXT NOT NULL, rounding TEXT NOT NULL, division TEXT NOT NULL, rhymeclass TEXT NOT NULL, repeating TEXT NOT NULL, tone TEXT NOT NULL, interpretation TEXT NOT NULL);"
                var statement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { sqlite3_finalize(statement); return }
                guard sqlite3_step(statement) == SQLITE_DONE else { sqlite3_finalize(statement); return }
                sqlite3_finalize(statement)
                let tableName: String = "gwongwan_table"
                let columns: String = "(code, word, rhyme, subrhyme, subrhymeserial, subrhymenumber, upper, lower, initial, rounding, division, rhymeclass, repeating, tone, interpretation)"
                guard let url = Bundle.module.url(forResource: "gwongwan", withExtension: "txt") else { return }
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
                let sourceLines: [String] = content.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)
                let valueBlocks = sourceLines.compactMap { sourceLine -> String? in
                        let parts = sourceLine.split(separator: ",")
                        guard parts.count == 14 else { return nil }
                        let word = parts[0]
                        guard let code = word.first?.decimalCode else { return nil }
                        let rhyme = parts[1]
                        let subrhyme = parts[2]
                        let subrhymeserial = parts[3]
                        let subrhymenumber = parts[4]
                        let upper = parts[5]
                        let lower = parts[6]
                        let initial = parts[7]
                        let rounding = parts[8]
                        let division = parts[9]
                        let rhymeclass = parts[10]
                        let repeating = parts[11]
                        let tone = parts[12]
                        let interpretation = parts[13]
                        return "(\(code), '\(word)', '\(rhyme)', '\(subrhyme)', \(subrhymeserial), \(subrhymenumber), '\(upper)', '\(lower)', '\(initial)', '\(rounding)', '\(division)', '\(rhymeclass)', '\(repeating)', '\(tone)', '\(interpretation)')"
                }
                let values: String = valueBlocks.joined(separator: ", ")
                insert(tableName: tableName, columns: columns, values: values)
        }
        private static func prepareDefinitionTable() async {
                let command: String = "CREATE TABLE definition_table (code INTEGER PRIMARY KEY, definition TEXT NOT NULL);"
                var statement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { sqlite3_finalize(statement); return }
                guard sqlite3_step(statement) == SQLITE_DONE else { sqlite3_finalize(statement); return }
                sqlite3_finalize(statement)
                let tableName: String = "definition_table"
                let columns: String = "(code, definition)"
                let tuples = UnihanDefinition.generate()
                let valueBlocks = tuples.map { tuple -> String in
                        let code = tuple.0
                        let definition = tuple.1
                        return "(\(code), '\(definition)')"
                }
                let values: String = valueBlocks.joined(separator: ", ")
                insert(tableName: tableName, columns: columns, values: values)
        }
}

private extension AppDataPreparer {
        static func insert(tableName: String, columns: String, values: String) {
                let command: String = "INSERT INTO \(tableName) \(columns) VALUES \(values);"
                var statement: OpaquePointer? = nil
                defer { sqlite3_finalize(statement) }
                guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else {
                        fatalError("Error occurred while preparing statement for table \(tableName)")
                }
                guard sqlite3_step(statement) == SQLITE_DONE else {
                        fatalError("Error occurred while inserting values to table \(tableName)")
                }
        }
}
