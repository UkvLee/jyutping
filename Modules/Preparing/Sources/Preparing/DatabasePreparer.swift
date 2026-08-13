import Foundation
import SQLite3
import CommonExtensions

struct DatabasePreparer {

        nonisolated(unsafe) private static let database: OpaquePointer? = {
                var db: OpaquePointer? = nil
                guard sqlite3_open_v2(":memory:", &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else { return nil }
                return db
        }()

        static func prepare() async {
                LexiconConverter.prepareJyutpingSourceLines()
                await withTaskGroup(of: Void.self) { group in
                        group.addTask { await prepareCoreLexiconTable() }
                        group.addTask { await prepareStructureTable() }
                        group.addTask { await preparePinyinTable() }
                        group.addTask { await prepareCangjieTable() }
                        group.addTask { await prepareQuickTable() }
                        group.addTask { await prepareStrokeTable() }
                        group.addTask { await prepareSymbolTable() }
                        group.addTask { await prepareEmojiSkinMapTable() }
                        group.addTask { await preparePlainTextTable() }
                        group.addTask { await prepareCoreSyllableTable() }
                        group.addTask { await prepareNineKeySyllableTable() }
                        group.addTask { await preparePinyinSyllableTable() }
                        group.addTask {
                                await prepareCharacterVariantTable(fileName: "CharacterVariant.AncientBooksPublishing", tableName: "variant_abp")
                        }
                        group.addTask {
                                await prepareCharacterVariantTable(fileName: "CharacterVariant.HongKong", tableName: "variant_hk")
                        }
                        group.addTask {
                                await prepareCharacterVariantTable(fileName: "CharacterVariant.Inherited", tableName: "variant_old")
                        }
                        group.addTask {
                                await prepareCharacterVariantTable(fileName: "CharacterVariant.PRCGeneral", tableName: "variant_prc")
                        }
                        group.addTask {
                                await prepareCharacterVariantTable(fileName: "CharacterVariant.Simplified", tableName: "variant_sim")
                        }
                        group.addTask {
                                await prepareCharacterVariantTable(fileName: "CharacterVariant.Taiwan", tableName: "variant_tw")
                        }
                        await group.waitForAll()
                }
                createIndexes()
                backupMobileDatabase()
                prepareDesktopDatabase()
                sqlite3_close_v2(database)
        }
        private static let coreIMEPackageURL: URL = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: "CoreIME")
        private static let mobileDatabaseURL = coreIMEPackageURL.appending(path: "Sources/CoreIMEMobileData/Resources/mobile.sqlite3")
        private static let desktopDatabaseURL = coreIMEPackageURL.appending(path: "Sources/CoreIMEDesktopData/Resources/desktop.sqlite3")

        private static func backupMobileDatabase() {
                let path = mobileDatabaseURL.path
                if FileManager.default.fileExists(atPath: path) {
                        try! FileManager.default.removeItem(atPath: path)
                }
                var destination: OpaquePointer? = nil
                defer { sqlite3_close_v2(destination) }
                guard sqlite3_open_v2(path, &destination, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
                        fatalError("Failed to create mobile.sqlite3")
                }
                let backup = sqlite3_backup_init(destination, "main", database, "main")
                guard sqlite3_backup_step(backup, -1) == SQLITE_DONE else {
                        sqlite3_backup_finish(backup)
                        fatalError("Failed to back up mobile.sqlite3")
                }
                guard sqlite3_backup_finish(backup) == SQLITE_OK else {
                        fatalError("Failed to finish backing up mobile.sqlite3")
                }
                optimize(destination)
        }
        private static func prepareDesktopDatabase() {
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: desktopDatabaseURL.path) {
                        try! fileManager.removeItem(at: desktopDatabaseURL)
                }
                try! fileManager.copyItem(at: mobileDatabaseURL, to: desktopDatabaseURL)
                var desktopDatabase: OpaquePointer? = nil
                defer { sqlite3_close_v2(desktopDatabase) }
                guard sqlite3_open_v2(desktopDatabaseURL.path, &desktopDatabase, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
                        fatalError("Failed to open desktop.sqlite3")
                }
                let commands: [String] = [
                        "DROP TABLE syllable_9key_table;",
                        "DROP INDEX ix_lexicon_core_anchors_9key;",
                        "DROP INDEX ix_lexicon_core_spell_9key;",
                        "DROP INDEX ix_structure_spell_9key;",
                        "DROP INDEX ix_pinyin_anchors_9key;",
                        "DROP INDEX ix_pinyin_spell_9key;",
                        "DROP INDEX ix_symbol_spell_9key;",
                        "DROP INDEX ix_plain_text_spell_9key;",
                        "ALTER TABLE lexicon_core DROP COLUMN anchors_9key;",
                        "ALTER TABLE lexicon_core DROP COLUMN spell_9key;",
                        "ALTER TABLE structure_table DROP COLUMN spell_9key;",
                        "ALTER TABLE pinyin_lexicon DROP COLUMN anchors_9key;",
                        "ALTER TABLE pinyin_lexicon DROP COLUMN spell_9key;",
                        "ALTER TABLE symbol_table DROP COLUMN spell_9key;",
                        "ALTER TABLE plain_text_table DROP COLUMN spell_9key;",
                        "ALTER TABLE syllable_pinyin_table DROP COLUMN code_9key;",
                ]
                commands.forEach({ execute($0, on: desktopDatabase) })
                optimize(desktopDatabase)
        }
        private static func optimize(_ destination: OpaquePointer?) {
                let commands: [String] = [
                        "PRAGMA page_size = 16384;",
                        "PRAGMA journal_mode = DELETE;",
                        "VACUUM;",
                        "ANALYZE;",
                ]
                commands.forEach({ execute($0, on: destination) })
        }
        private static func execute(_ command: String, on destination: OpaquePointer?) {
                var errorMessage: UnsafeMutablePointer<CChar>? = nil
                guard sqlite3_exec(destination, command, nil, nil, &errorMessage) == SQLITE_OK else {
                        let message = errorMessage.map({ String(cString: $0) }) ?? "Unknown SQLite error"
                        sqlite3_free(errorMessage)
                        fatalError("\(message): \(command)")
                }
        }

        private static func createIndexes() {
                let commands: [String] = [
                        "CREATE INDEX ix_lexicon_core_anchors ON lexicon_core (anchors, char_count);",
                        "CREATE INDEX ix_lexicon_core_spell ON lexicon_core (spell, complexity);",
                        "CREATE INDEX ix_lexicon_core_anchors_9key ON lexicon_core (anchors_9key, char_count);",
                        "CREATE INDEX ix_lexicon_core_spell_9key ON lexicon_core (spell_9key, complexity);",
                        "CREATE INDEX ix_lexicon_core_word ON lexicon_core (word);",

                        "CREATE INDEX ix_structure_spell ON structure_table (spell, complexity);",
                        "CREATE INDEX ix_structure_spell_9key ON structure_table (spell_9key, complexity);",

                        "CREATE INDEX ix_pinyin_anchors ON pinyin_lexicon (anchors, char_count);",
                        "CREATE INDEX ix_pinyin_spell ON pinyin_lexicon (spell, complexity);",
                        "CREATE INDEX ix_pinyin_anchors_9key ON pinyin_lexicon (anchors_9key, char_count);",
                        "CREATE INDEX ix_pinyin_spell_9key ON pinyin_lexicon (spell_9key, complexity);",

                        "CREATE INDEX ix_cangjie_cangjie5 ON cangjie_table (cangjie5, c5complex);",
                        "CREATE INDEX ix_cangjie_c5code ON cangjie_table (c5code);",
                        "CREATE INDEX ix_cangjie_cangjie3 ON cangjie_table (cangjie3, c3complex);",
                        "CREATE INDEX ix_cangjie_c3code ON cangjie_table (c3code);",

                        "CREATE INDEX ix_quick_quick5 ON quick_table (quick5, q5complex);",
                        "CREATE INDEX ix_quick_q5code ON quick_table (q5code);",
                        "CREATE INDEX ix_quick_quick3 ON quick_table (quick3, q3complex);",
                        "CREATE INDEX ix_quick_q3code ON quick_table (q3code);",

                        "CREATE INDEX ix_stroke_stroke ON stroke_table (stroke, complex);",
                        "CREATE INDEX ix_stroke_code ON stroke_table (code, complex);",

                        "CREATE INDEX ix_symbol_spell ON symbol_table (spell, complexity);",
                        "CREATE INDEX ix_symbol_spell_9key ON symbol_table (spell_9key, complexity);",
                        "CREATE INDEX ix_emoji_skin_map_source ON emoji_skin_map (source);",

                        "CREATE INDEX ix_plain_text_spell ON plain_text_table (spell, letter_count);",
                        "CREATE INDEX ix_plain_text_spell_9key ON plain_text_table (spell_9key, letter_count);",
                ]
                for command in commands {
                        var statement: OpaquePointer? = nil
                        defer { sqlite3_finalize(statement) }
                        guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { return }
                        guard sqlite3_step(statement) == SQLITE_DONE else { return }
                }
        }

        private static func prepareCoreLexiconTable() async {
                let command: String = "CREATE TABLE lexicon_core (id INTEGER PRIMARY KEY AUTOINCREMENT, word TEXT NOT NULL, romanization TEXT NOT NULL, char_count INTEGER NOT NULL, complexity INTEGER NOT NULL, anchors INTEGER NOT NULL, spell INTEGER NOT NULL, anchors_9key INTEGER NOT NULL, spell_9key INTEGER NOT NULL);"
                var statement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { sqlite3_finalize(statement); return }
                guard sqlite3_step(statement) == SQLITE_DONE else { sqlite3_finalize(statement); return }
                sqlite3_finalize(statement)
                let tableName: String = "lexicon_core"
                let columns: String = "(word, romanization, char_count, complexity, anchors, spell, anchors_9key, spell_9key)"
                let sourceEntries: [LexiconEntry] = LexiconConverter.jyutping()
                let steps: Range<Int> = 0..<2000
                let stepSize: Int = sourceEntries.count / 2000
                for step in steps {
                        let lower: Int = step * stepSize
                        let upper: Int = (step == 1999) ? sourceEntries.count : ((step + 1) * stepSize)
                        let part = sourceEntries[lower..<upper]
                        let valueBlocks = part.map({ entry -> String in
                                return "('\(entry.word)', '\(entry.romanization)', \(entry.charCount), \(entry.complexity), \(entry.anchors), \(entry.spell), \(entry.nineKeyAnchors), \(entry.nineKeySpell))"
                        })
                        let values: String = valueBlocks.joined(separator: ", ")
                        insert(tableName: tableName, columns: columns, values: values)
                }
        }
        private static func prepareCharacterVariantTable(fileName: String, tableName: String) async {
                let command: String = "CREATE TABLE \(tableName) (source INTEGER PRIMARY KEY, target INTEGER NOT NULL);"
                var statement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { sqlite3_finalize(statement); return }
                guard sqlite3_step(statement) == SQLITE_DONE else { sqlite3_finalize(statement); return }
                sqlite3_finalize(statement)
                let columns: String = "(source, target)"
                guard let sourceUrl: URL = Bundle.module.url(forResource: fileName, withExtension: "txt") else { fatalError("Can not load file \(fileName).txt") }
                let valueBlocks = CharacterVariant.generate(sourceUrl).map({ "(\($0.left), \($0.right))" })
                let values: String = valueBlocks.joined(separator: ", ")
                insert(tableName: tableName, columns: columns, values: values)
        }
        private static func prepareStructureTable() async {
                let command: String = "CREATE TABLE structure_table (id INTEGER PRIMARY KEY AUTOINCREMENT, word TEXT NOT NULL, romanization TEXT NOT NULL, char_count INTEGER NOT NULL, complexity INTEGER NOT NULL, spell INTEGER NOT NULL, spell_9key INTEGER NOT NULL);"
                var statement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { sqlite3_finalize(statement); return }
                guard sqlite3_step(statement) == SQLITE_DONE else { sqlite3_finalize(statement); return }
                sqlite3_finalize(statement)
                let tableName: String = "structure_table"
                let columns: String = "(word, romanization, char_count, complexity, spell, spell_9key)"
                let sourceEntries: [LexiconEntry] = LexiconConverter.structure()
                let steps: Range<Int> = 0..<200
                let stepSize: Int = sourceEntries.count / 200
                for step in steps {
                        let lower: Int = step * stepSize
                        let upper: Int = (step == 199) ? sourceEntries.count : ((step + 1) * stepSize)
                        let part = sourceEntries[lower..<upper]
                        let valueBlocks = part.map({ entry -> String in
                                return "('\(entry.word)', '\(entry.romanization)', \(entry.charCount), \(entry.complexity), \(entry.spell), \(entry.nineKeySpell))"
                        })
                        let values: String = valueBlocks.joined(separator: ", ")
                        insert(tableName: tableName, columns: columns, values: values)
                }
        }
        private static func preparePinyinTable() async {
                let command: String = "CREATE TABLE pinyin_lexicon (id INTEGER PRIMARY KEY AUTOINCREMENT, word TEXT NOT NULL, romanization TEXT NOT NULL, char_count INTEGER NOT NULL, complexity INTEGER NOT NULL, anchors INTEGER NOT NULL, spell INTEGER NOT NULL, anchors_9key INTEGER NOT NULL, spell_9key INTEGER NOT NULL);"
                var statement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { sqlite3_finalize(statement); return }
                guard sqlite3_step(statement) == SQLITE_DONE else { sqlite3_finalize(statement); return }
                sqlite3_finalize(statement)
                let tableName: String = "pinyin_lexicon"
                let columns: String = "(word, romanization, char_count, complexity, anchors, spell, anchors_9key, spell_9key)"
                let sourceEntries: [LexiconEntry] = LexiconConverter.pinyin()
                let steps: Range<Int> = 0..<2000
                let stepSize: Int = sourceEntries.count / 2000
                for step in steps {
                        let lower: Int = step * stepSize
                        let upper: Int = (step == 1999) ? sourceEntries.count : ((step + 1) * stepSize)
                        let part = sourceEntries[lower..<upper]
                        let valueBlocks = part.map({ entry -> String in
                                return "('\(entry.word)', '\(entry.romanization)', \(entry.charCount), \(entry.complexity), \(entry.anchors), \(entry.spell), \(entry.nineKeyAnchors), \(entry.nineKeySpell))"
                        })
                        let values: String = valueBlocks.joined(separator: ", ")
                        insert(tableName: tableName, columns: columns, values: values)
                }
        }
        private static func prepareCangjieTable() async {
                let command: String = "CREATE TABLE cangjie_table (id INTEGER PRIMARY KEY AUTOINCREMENT, word TEXT NOT NULL, cangjie5 TEXT NOT NULL, c5complex INTEGER NOT NULL, c5code INTEGER NOT NULL, cangjie3 TEXT NOT NULL, c3complex INTEGER NOT NULL, c3code INTEGER NOT NULL);"
                var statement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { sqlite3_finalize(statement); return }
                guard sqlite3_step(statement) == SQLITE_DONE else { sqlite3_finalize(statement); return }
                sqlite3_finalize(statement)
                let tableName: String = "cangjie_table"
                let columns: String = "(word, cangjie5, c5complex, c5code, cangjie3, c3complex, c3code)"
                let sourceEntries = Cangjie.generate()
                let valueBlocks = sourceEntries.map { entry -> String in
                        return "('\(entry.word)', '\(entry.cangjie5)', \(entry.c5complex), \(entry.c5code), '\(entry.cangjie3)', \(entry.c3complex), \(entry.c3code))"
                }
                let values: String = valueBlocks.joined(separator: ", ")
                insert(tableName: tableName, columns: columns, values: values)
        }
        private static func prepareQuickTable() async {
                let command: String = "CREATE TABLE quick_table (id INTEGER PRIMARY KEY AUTOINCREMENT, word TEXT NOT NULL, quick5 TEXT NOT NULL, q5complex INTEGER NOT NULL, q5code INTEGER NOT NULL, quick3 TEXT NOT NULL, q3complex INTEGER NOT NULL, q3code INTEGER NOT NULL);"
                var statement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { sqlite3_finalize(statement); return }
                guard sqlite3_step(statement) == SQLITE_DONE else { sqlite3_finalize(statement); return }
                sqlite3_finalize(statement)
                let tableName: String = "quick_table"
                let columns: String = "(word, quick5, q5complex, q5code, quick3, q3complex, q3code)"
                let sourceEntries = Quick.generate()
                let steps: Range<Int> = 0..<2000
                let stepSize: Int = sourceEntries.count / 2000
                for step in steps {
                        let lower: Int = step * stepSize
                        let upper: Int = (step == 1999) ? sourceEntries.count : ((step + 1) * stepSize)
                        let part = sourceEntries[lower..<upper]
                        let valueBlocks = part.map({ entry -> String in
                                return "('\(entry.word)', '\(entry.quick5)', \(entry.q5complex), \(entry.q5code), '\(entry.quick3)', \(entry.q3complex), \(entry.q3code))"
                        })
                        let values: String = valueBlocks.joined(separator: ", ")
                        insert(tableName: tableName, columns: columns, values: values)
                }
        }
        private static func prepareStrokeTable() async {
                let command: String = "CREATE TABLE stroke_table (id INTEGER PRIMARY KEY AUTOINCREMENT, word TEXT NOT NULL, stroke TEXT NOT NULL, complex INTEGER NOT NULL, code INTEGER NOT NULL);"
                var statement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { sqlite3_finalize(statement); return }
                guard sqlite3_step(statement) == SQLITE_DONE else { sqlite3_finalize(statement); return }
                sqlite3_finalize(statement)
                let tableName: String = "stroke_table"
                let columns: String = "(word, stroke, complex, code)"
                let sourceEntries = Stroke.generate()
                let steps: Range<Int> = 0..<2000
                let stepSize: Int = sourceEntries.count / 2000
                for step in steps {
                        let lower: Int = step * stepSize
                        let upper: Int = (step == 1999) ? sourceEntries.count : ((step + 1) * stepSize)
                        let part = sourceEntries[lower..<upper]
                        let valueBlocks = part.map({ entry -> String in
                                return "('\(entry.word)', '\(entry.stroke)', \(entry.complex), \(entry.code))"
                        })
                        let values: String = valueBlocks.joined(separator: ", ")
                        insert(tableName: tableName, columns: columns, values: values)
                }
        }
        private static func prepareSymbolTable() async {
                let command: String = "CREATE TABLE symbol_table (id INTEGER PRIMARY KEY AUTOINCREMENT, category INTEGER NOT NULL, unicode_version INTEGER NOT NULL, code_point TEXT NOT NULL, cantonese TEXT NOT NULL, romanization TEXT NOT NULL, complexity INTEGER NOT NULL, spell INTEGER NOT NULL, spell_9key INTEGER NOT NULL);"
                var statement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { sqlite3_finalize(statement); return }
                guard sqlite3_step(statement) == SQLITE_DONE else { sqlite3_finalize(statement); return }
                sqlite3_finalize(statement)
                let tableName: String = "symbol_table"
                let columns: String = "(category, unicode_version, code_point, cantonese, romanization, complexity, spell, spell_9key)"
                guard let url = Bundle.module.url(forResource: "symbol", withExtension: "txt") else { return }
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
                let sourceLines: [String] = content.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)
                let steps: Range<Int> = 0..<100
                let stepSize: Int = sourceLines.count / 100
                for step in steps {
                        let lower: Int = step * stepSize
                        let upper: Int = (step == 99) ? sourceLines.count : ((step + 1) * stepSize)
                        let part = sourceLines[lower..<upper]
                        let valueBlocks = part.compactMap({ line -> String? in
                                let parts = line.split(separator: "\t")
                                guard parts.count == 5 else { return nil }
                                let category = parts[0]
                                let version = parts[1]
                                let codePoint = parts[2]
                                let cantonese = parts[3]
                                let romanization = parts[4]
                                let complexity: Int = romanization.split(separator: Character.space).map({ $0.count - 1 }).decimalOverflowed()
                                let letters = romanization.filter(\.isLowercaseBasicLatinLetter)
                                let spell = letters.serialCode
                                let nineKeySpell = letters.keypadCode
                                return "(\(category), \(version), '\(codePoint)', '\(cantonese)', '\(romanization)', \(complexity), \(spell), \(nineKeySpell))"
                        })
                        let values: String = valueBlocks.joined(separator: ", ")
                        insert(tableName: tableName, columns: columns, values: values)
                }
        }
        private static func prepareEmojiSkinMapTable() async {
                let command: String = "CREATE TABLE emoji_skin_map (id INTEGER PRIMARY KEY AUTOINCREMENT, source TEXT NOT NULL, target TEXT NOT NULL);"
                var statement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { sqlite3_finalize(statement); return }
                guard sqlite3_step(statement) == SQLITE_DONE else { sqlite3_finalize(statement); return }
                sqlite3_finalize(statement)
                let tableName: String = "emoji_skin_map"
                let columns: String = "(source, target)"
                guard let url = Bundle.module.url(forResource: "skin-tone-map", withExtension: "txt") else { return }
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
                let sourceLines: [String] = content.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)
                let valueBlocks = sourceLines.compactMap { line -> String? in
                        let parts = line.split(separator: "\t")
                        guard parts.count == 2 else { return nil }
                        let source = parts[0]
                        let target = parts[1]
                        return "('\(source)', '\(target)')"
                }
                let values: String = valueBlocks.joined(separator: ", ")
                insert(tableName: tableName, columns: columns, values: values)
        }
        private static func preparePlainTextTable() async {
                let command: String = "CREATE TABLE plain_text_table (id INTEGER PRIMARY KEY AUTOINCREMENT, input TEXT NOT NULL, word TEXT NOT NULL, letter_count INTEGER NOT NULL, spell INTEGER NOT NULL, spell_9key INTEGER NOT NULL);"
                var statement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { sqlite3_finalize(statement); return }
                guard sqlite3_step(statement) == SQLITE_DONE else { sqlite3_finalize(statement); return }
                sqlite3_finalize(statement)
                let tableName: String = "plain_text_table"
                let columns: String = "(input, word, letter_count, spell, spell_9key)"
                let sourceEntries = PlainText.convert()
                let steps: Range<Int> = 0..<200
                let stepSize: Int = sourceEntries.count / 200
                for step in steps {
                        let lower: Int = step * stepSize
                        let upper: Int = (step == 199) ? sourceEntries.count : ((step + 1) * stepSize)
                        let part = sourceEntries[lower..<upper]
                        let valueBlocks = part.map({ entry -> String in
                                let escapedWord: String = entry.word.contains(String.apostrophe) ? entry.word.replacingOccurrences(of: "'", with: "''") : entry.word
                                return "('\(entry.input)', '\(escapedWord)', \(entry.letterCount), \(entry.spell), \(entry.nineKeySpell))"
                        })
                        let values: String = valueBlocks.joined(separator: ", ")
                        insert(tableName: tableName, columns: columns, values: values)
                }
        }
        private static func prepareCoreSyllableTable() async {
                let command: String = "CREATE TABLE syllable_core_table (alias_code INTEGER PRIMARY KEY, origin_code INTEGER NOT NULL, alias TEXT NOT NULL, origin TEXT NOT NULL);"
                var statement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { sqlite3_finalize(statement); return }
                guard sqlite3_step(statement) == SQLITE_DONE else { sqlite3_finalize(statement); return }
                sqlite3_finalize(statement)
                let tableName: String = "syllable_core_table"
                let columns: String = "(alias_code, origin_code, alias, origin)"
                guard let url = Bundle.module.url(forResource: "syllable-core", withExtension: "txt") else { return }
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
                let sourceLines: [String] = content
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .components(separatedBy: .newlines)
                        .map({ $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: .controlCharacters) })
                        .filter(\.isNotEmpty)
                let valueBlocks = sourceLines.compactMap { line -> String? in
                        lazy var errorMessage: String = "syllable.txt : bad format : \(line)"
                        let parts = line.split(separator: "\t")
                        guard parts.count == 2 else { fatalError(errorMessage) }
                        let alias = parts[0]
                        let origin = parts[1]
                        let aliasCode = alias.serialCode
                        let originCode = origin.serialCode
                        return "(\(aliasCode), \(originCode), '\(alias)', '\(origin)')"
                }
                let values: String = valueBlocks.joined(separator: ", ")
                insert(tableName: tableName, columns: columns, values: values)
        }
        private static func prepareNineKeySyllableTable() async {
                let command: String = "CREATE TABLE syllable_9key_table (alias_code INTEGER PRIMARY KEY, origin_code INTEGER NOT NULL, alias_9key_code INTEGER NOT NULL, origin_9key_code INTEGER NOT NULL, alias TEXT NOT NULL, origin TEXT NOT NULL);"
                var statement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { sqlite3_finalize(statement); return }
                guard sqlite3_step(statement) == SQLITE_DONE else { sqlite3_finalize(statement); return }
                sqlite3_finalize(statement)
                let tableName: String = "syllable_9key_table"
                let columns: String = "(alias_code, origin_code, alias_9key_code, origin_9key_code, alias, origin)"
                guard let url = Bundle.module.url(forResource: "syllable-9key", withExtension: "txt") else { fatalError("Failed to get URL of syllable-9key.txt") }
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { fatalError("Failed to read syllable-9key.txt") }
                let sourceLines: [String] = content
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .components(separatedBy: .newlines)
                        .map({ $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: .controlCharacters) })
                        .filter(\.isNotEmpty)
                let valueBlocks = sourceLines.compactMap { line -> String? in
                        lazy var errorMessage: String = "syllable-9key.txt : bad format : \(line)"
                        let parts = line.split(separator: "\t")
                        guard parts.count == 2 else { fatalError(errorMessage) }
                        let alias = parts[0]
                        let origin = parts[1]
                        let aliasCode = alias.serialCode
                        let originCode = origin.serialCode
                        let nineKeyAlias = alias.keypadCode
                        let nineKeyOrigin = origin.keypadCode
                        return "(\(aliasCode), \(originCode), \(nineKeyAlias), \(nineKeyOrigin), '\(alias)', '\(origin)')"
                }
                let values: String = valueBlocks.joined(separator: ", ")
                insert(tableName: tableName, columns: columns, values: values)
        }
        private static func preparePinyinSyllableTable() async {
                let command: String = "CREATE TABLE syllable_pinyin_table (code INTEGER PRIMARY KEY, code_9key INTEGER NOT NULL, syllable TEXT NOT NULL);"
                var statement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { sqlite3_finalize(statement); return }
                guard sqlite3_step(statement) == SQLITE_DONE else { sqlite3_finalize(statement); return }
                sqlite3_finalize(statement)
                let tableName: String = "syllable_pinyin_table"
                let columns: String = "(code, code_9key, syllable)"
                guard let url = Bundle.module.url(forResource: "syllable-pinyin", withExtension: "txt") else { return }
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
                let sourceLines: [String] = content
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .components(separatedBy: .newlines)
                        .map({ $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: .controlCharacters) })
                        .filter(\.isNotEmpty)
                let valueBlocks = sourceLines.compactMap { syllable -> String? in
                        lazy var errorMessage: String = "syllable-pinyin.txt : bad format : \(syllable)"
                        return "(\(syllable.serialCode), \(syllable.keypadCode), '\(syllable)')"
                }
                let values: String = valueBlocks.joined(separator: ", ")
                insert(tableName: tableName, columns: columns, values: values)
        }
}

private extension DatabasePreparer {
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
