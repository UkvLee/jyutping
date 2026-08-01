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
                Cangjie.prepareCangjieDatabase()
                await withTaskGroup(of: Void.self) { group in
                        group.addTask { await createCoreLexiconTable() }
                        group.addTask { await createStructureTable() }
                        group.addTask { await createPinyinTable() }
                        group.addTask { await createCangjieTable() }
                        group.addTask { await createQuickTable() }
                        group.addTask { await createStrokeTable() }
                        group.addTask { await createSymbolTable() }
                        group.addTask { await createEmojiSkinMapTable() }
                        group.addTask { await createTextMarkTable() }
                        group.addTask { await createCoreSyllableTable() }
                        group.addTask { await createNineKeySyllableTable() }
                        group.addTask { await createPinyinSyllableTable() }
                        group.addTask {
                                await createCharacterVariantTable(fileName: "CharacterVariant.AncientBooksPublishing", tableName: "variant_abp")
                        }
                        group.addTask {
                                await createCharacterVariantTable(fileName: "CharacterVariant.HongKong", tableName: "variant_hk")
                        }
                        group.addTask {
                                await createCharacterVariantTable(fileName: "CharacterVariant.Inherited", tableName: "variant_old")
                        }
                        group.addTask {
                                await createCharacterVariantTable(fileName: "CharacterVariant.PRCGeneral", tableName: "variant_prc")
                        }
                        group.addTask {
                                await createCharacterVariantTable(fileName: "CharacterVariant.Simplified", tableName: "variant_sim")
                        }
                        group.addTask {
                                await createCharacterVariantTable(fileName: "CharacterVariant.Taiwan", tableName: "variant_tw")
                        }
                        await group.waitForAll()
                }
                createIndexes()
                backupInMemoryDatabase()
                sqlite3_close_v2(database)
                Cangjie.closeCangjieDatabase()
        }
        private static func backupInMemoryDatabase() {
                let path = "../CoreIME/Sources/CoreIME/Resources/ime.sqlite3"
                if FileManager.default.fileExists(atPath: path) {
                        try? FileManager.default.removeItem(atPath: path)
                }
                var destination: OpaquePointer? = nil
                defer { sqlite3_close_v2(destination) }
                guard sqlite3_open_v2(path, &destination, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else { return }
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

                        "CREATE INDEX ix_mark_spell ON mark_table (spell, letter_count);",
                        "CREATE INDEX ix_mark_spell_9key ON mark_table (spell_9key, letter_count);",

                        // "CREATE INDEX ix_variant_abp_source ON variant_abp (source);",
                        "CREATE INDEX ix_variant_abp_target ON variant_abp (target);",

                        // "CREATE INDEX ix_variant_hk_source ON variant_hk (source);",
                        "CREATE INDEX ix_variant_hk_target ON variant_hk (target);",

                        // "CREATE INDEX ix_variant_old_source ON variant_old (source);",
                        "CREATE INDEX ix_variant_old_target ON variant_old (target);",

                        // "CREATE INDEX ix_variant_prc_source ON variant_prc (source);",
                        "CREATE INDEX ix_variant_prc_target ON variant_prc (target);",

                        // "CREATE INDEX ix_variant_sim_source ON variant_sim (source);",
                        "CREATE INDEX ix_variant_sim_target ON variant_sim (target);",

                        // "CREATE INDEX ix_variant_tw_source ON variant_tw (source);",
                        "CREATE INDEX ix_variant_tw_target ON variant_tw (target);",
                ]
                for command in commands {
                        var statement: OpaquePointer? = nil
                        defer { sqlite3_finalize(statement) }
                        guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { return }
                        guard sqlite3_step(statement) == SQLITE_DONE else { return }
                }
        }

        private static func createCoreLexiconTable() async {
                let createTable: String = "CREATE TABLE lexicon_core (id INTEGER PRIMARY KEY AUTOINCREMENT, word TEXT NOT NULL, romanization TEXT NOT NULL, char_count INTEGER NOT NULL, complexity INTEGER NOT NULL, anchors INTEGER NOT NULL, spell INTEGER NOT NULL, anchors_9key INTEGER NOT NULL, spell_9key INTEGER NOT NULL, UNIQUE (word, romanization));"
                var createStatement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, createTable, -1, &createStatement, nil) == SQLITE_OK else { sqlite3_finalize(createStatement); return }
                guard sqlite3_step(createStatement) == SQLITE_DONE else { sqlite3_finalize(createStatement); return }
                sqlite3_finalize(createStatement)
                let sourceEntries: [LexiconEntry] = LexiconConverter.jyutping()
                func insert(values: String) {
                        let insert: String = "INSERT INTO lexicon_core (word, romanization, char_count, complexity, anchors, spell, anchors_9key, spell_9key) VALUES \(values);"
                        var insertStatement: OpaquePointer? = nil
                        defer { sqlite3_finalize(insertStatement) }
                        guard sqlite3_prepare_v2(database, insert, -1, &insertStatement, nil) == SQLITE_OK else { return }
                        guard sqlite3_step(insertStatement) == SQLITE_DONE else { return }
                }
                let range: Range<Int> = 0..<2000
                let distance: Int = sourceEntries.count / 2000
                for number in range {
                        let bound: Int = (number == 1999) ? sourceEntries.count : ((number + 1) * distance)
                        let part = sourceEntries[(number * distance)..<bound]
                        let entries = part.map({ entry -> String in
                                return "('\(entry.word)', '\(entry.romanization)', \(entry.charCount), \(entry.complexity), \(entry.anchors), \(entry.spell), \(entry.nineKeyAnchors), \(entry.nineKeySpell))"
                        })
                        let values: String = entries.joined(separator: ", ")
                        insert(values: values)
                }
        }
        private static func createCharacterVariantTable(fileName: String, tableName: String) async {
                let createTable: String = "CREATE TABLE \(tableName) (source INTEGER PRIMARY KEY, target INTEGER NOT NULL);"
                var createStatement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, createTable, -1, &createStatement, nil) == SQLITE_OK else { sqlite3_finalize(createStatement); return }
                guard sqlite3_step(createStatement) == SQLITE_DONE else { sqlite3_finalize(createStatement); return }
                sqlite3_finalize(createStatement)
                guard let sourceUrl: URL = Bundle.module.url(forResource: fileName, withExtension: "txt") else { fatalError("Can not load file \(fileName).txt") }
                let values: String = CharacterVariant.generate(sourceUrl).map({ "(\($0.left), \($0.right))" }).joined(separator: ", ")
                let insert: String = "INSERT INTO \(tableName) (source, target) VALUES \(values);"
                var insertStatement: OpaquePointer? = nil
                defer { sqlite3_finalize(insertStatement) }
                guard sqlite3_prepare_v2(database, insert, -1, &insertStatement, nil) == SQLITE_OK else { return }
                guard sqlite3_step(insertStatement) == SQLITE_DONE else { return }
        }
        private static func createStructureTable() async {
                let createTable: String = "CREATE TABLE structure_table (id INTEGER PRIMARY KEY AUTOINCREMENT, word TEXT NOT NULL, romanization TEXT NOT NULL, char_count INTEGER NOT NULL, complexity INTEGER NOT NULL, spell INTEGER NOT NULL, spell_9key INTEGER NOT NULL);"
                var createStatement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, createTable, -1, &createStatement, nil) == SQLITE_OK else { sqlite3_finalize(createStatement); return }
                guard sqlite3_step(createStatement) == SQLITE_DONE else { sqlite3_finalize(createStatement); return }
                sqlite3_finalize(createStatement)
                let sourceEntries: [LexiconEntry] = LexiconConverter.structure()
                func insert(values: String) {
                        let insert: String = "INSERT INTO structure_table (word, romanization, char_count, complexity, spell, spell_9key) VALUES \(values);"
                        var insertStatement: OpaquePointer? = nil
                        defer { sqlite3_finalize(insertStatement) }
                        guard sqlite3_prepare_v2(database, insert, -1, &insertStatement, nil) == SQLITE_OK else { return }
                        guard sqlite3_step(insertStatement) == SQLITE_DONE else { return }
                }
                let range: Range<Int> = 0..<200
                let distance: Int = sourceEntries.count / 200
                for number in range {
                        let bound: Int = (number == 199) ? sourceEntries.count : ((number + 1) * distance)
                        let part = sourceEntries[(number * distance)..<bound]
                        let entries = part.map({ entry -> String in
                                return "('\(entry.word)', '\(entry.romanization)', \(entry.charCount), \(entry.complexity), \(entry.spell), \(entry.nineKeySpell))"
                        })
                        let values: String = entries.joined(separator: ", ")
                        insert(values: values)
                }
        }
        private static func createPinyinTable() async {
                let createTable: String = "CREATE TABLE pinyin_lexicon (id INTEGER PRIMARY KEY AUTOINCREMENT, word TEXT NOT NULL, romanization TEXT NOT NULL, char_count INTEGER NOT NULL, complexity INTEGER NOT NULL, anchors INTEGER NOT NULL, spell INTEGER NOT NULL, anchors_9key INTEGER NOT NULL, spell_9key INTEGER NOT NULL);"
                var createStatement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, createTable, -1, &createStatement, nil) == SQLITE_OK else { sqlite3_finalize(createStatement); return }
                guard sqlite3_step(createStatement) == SQLITE_DONE else { sqlite3_finalize(createStatement); return }
                sqlite3_finalize(createStatement)
                let sourceEntries: [LexiconEntry] = LexiconConverter.pinyin()
                func insert(values: String) {
                        let insert: String = "INSERT INTO pinyin_lexicon (word, romanization, char_count, complexity, anchors, spell, anchors_9key, spell_9key) VALUES \(values);"
                        var insertStatement: OpaquePointer? = nil
                        defer { sqlite3_finalize(insertStatement) }
                        guard sqlite3_prepare_v2(database, insert, -1, &insertStatement, nil) == SQLITE_OK else { return }
                        guard sqlite3_step(insertStatement) == SQLITE_DONE else { return }
                }
                let range: Range<Int> = 0..<2000
                let distance: Int = sourceEntries.count / 2000
                for number in range {
                        let bound: Int = (number == 1999) ? sourceEntries.count : ((number + 1) * distance)
                        let part = sourceEntries[(number * distance)..<bound]
                        let entries = part.map({ entry -> String in
                                return "('\(entry.word)', '\(entry.romanization)', \(entry.charCount), \(entry.complexity), \(entry.anchors), \(entry.spell), \(entry.nineKeyAnchors), \(entry.nineKeySpell))"
                        })
                        let values: String = entries.joined(separator: ", ")
                        insert(values: values)
                }
        }
        private static func createCangjieTable() async {
                let createTable: String = "CREATE TABLE cangjie_table (id INTEGER PRIMARY KEY AUTOINCREMENT, word TEXT NOT NULL, cangjie5 TEXT NOT NULL, c5complex INTEGER NOT NULL, c5code INTEGER NOT NULL, cangjie3 TEXT NOT NULL, c3complex INTEGER NOT NULL, c3code INTEGER NOT NULL);"
                var createStatement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, createTable, -1, &createStatement, nil) == SQLITE_OK else { sqlite3_finalize(createStatement); return }
                guard sqlite3_step(createStatement) == SQLITE_DONE else { sqlite3_finalize(createStatement); return }
                sqlite3_finalize(createStatement)
                let sourceEntries = Cangjie.generate()
                let entries = sourceEntries.map { entry -> String in
                        return "('\(entry.word)', '\(entry.cangjie5)', \(entry.c5complex), \(entry.c5code), '\(entry.cangjie3)', \(entry.c3complex), \(entry.c3code))"
                }
                let values: String = entries.joined(separator: ", ")
                let insert: String = "INSERT INTO cangjie_table (word, cangjie5, c5complex, c5code, cangjie3, c3complex, c3code) VALUES \(values);"
                var insertStatement: OpaquePointer? = nil
                defer { sqlite3_finalize(insertStatement) }
                guard sqlite3_prepare_v2(database, insert, -1, &insertStatement, nil) == SQLITE_OK else { return }
                guard sqlite3_step(insertStatement) == SQLITE_DONE else { return }
        }
        private static func createQuickTable() async {
                let createTable: String = "CREATE TABLE quick_table (id INTEGER PRIMARY KEY AUTOINCREMENT, word TEXT NOT NULL, quick5 TEXT NOT NULL, q5complex INTEGER NOT NULL, q5code INTEGER NOT NULL, quick3 TEXT NOT NULL, q3complex INTEGER NOT NULL, q3code INTEGER NOT NULL);"
                var createStatement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, createTable, -1, &createStatement, nil) == SQLITE_OK else { sqlite3_finalize(createStatement); return }
                guard sqlite3_step(createStatement) == SQLITE_DONE else { sqlite3_finalize(createStatement); return }
                sqlite3_finalize(createStatement)
                let sourceEntries = Quick.generate()
                func insert(values: String) {
                        let insert: String = "INSERT INTO quick_table (word, quick5, q5complex, q5code, quick3, q3complex, q3code) VALUES \(values);"
                        var insertStatement: OpaquePointer? = nil
                        defer { sqlite3_finalize(insertStatement) }
                        guard sqlite3_prepare_v2(database, insert, -1, &insertStatement, nil) == SQLITE_OK else { return }
                        guard sqlite3_step(insertStatement) == SQLITE_DONE else { return }
                }
                let range: Range<Int> = 0..<2000
                let distance: Int = sourceEntries.count / 2000
                for number in range {
                        let bound: Int = number == 1999 ? sourceEntries.count : ((number + 1) * distance)
                        let part = sourceEntries[(number * distance)..<bound]
                        let entries = part.map { entry -> String in
                                return "('\(entry.word)', '\(entry.quick5)', \(entry.q5complex), \(entry.q5code), '\(entry.quick3)', \(entry.q3complex), \(entry.q3code))"
                        }
                        let values: String = entries.joined(separator: ", ")
                        insert(values: values)
                }
        }
        private static func createStrokeTable() async {
                let createTable: String = "CREATE TABLE stroke_table (id INTEGER PRIMARY KEY AUTOINCREMENT, word TEXT NOT NULL, stroke TEXT NOT NULL, complex INTEGER NOT NULL, code INTEGER NOT NULL);"
                var createStatement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, createTable, -1, &createStatement, nil) == SQLITE_OK else { sqlite3_finalize(createStatement); return }
                guard sqlite3_step(createStatement) == SQLITE_DONE else { sqlite3_finalize(createStatement); return }
                sqlite3_finalize(createStatement)
                let sourceEntries = Stroke.generate()
                func insert(values: String) {
                        let insert: String = "INSERT INTO stroke_table (word, stroke, complex, code) VALUES \(values);"
                        var insertStatement: OpaquePointer? = nil
                        defer { sqlite3_finalize(insertStatement) }
                        guard sqlite3_prepare_v2(database, insert, -1, &insertStatement, nil) == SQLITE_OK else { return }
                        guard sqlite3_step(insertStatement) == SQLITE_DONE else { return }
                }
                let range: Range<Int> = 0..<2000
                let distance: Int = sourceEntries.count / 2000
                for number in range {
                        let bound: Int = number == 1999 ? sourceEntries.count : ((number + 1) * distance)
                        let part = sourceEntries[(number * distance)..<bound]
                        let entries = part.map { entry -> String in
                                return "('\(entry.word)', '\(entry.stroke)', \(entry.complex), \(entry.code))"
                        }
                        let values: String = entries.joined(separator: ", ")
                        insert(values: values)
                }
        }
        private static func createSymbolTable() async {
                let createTable: String = "CREATE TABLE symbol_table (id INTEGER PRIMARY KEY AUTOINCREMENT, category INTEGER NOT NULL, unicode_version INTEGER NOT NULL, code_point TEXT NOT NULL, cantonese TEXT NOT NULL, romanization TEXT NOT NULL, complexity INTEGER NOT NULL, spell INTEGER NOT NULL, spell_9key INTEGER NOT NULL);"
                var createStatement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, createTable, -1, &createStatement, nil) == SQLITE_OK else { sqlite3_finalize(createStatement); return }
                guard sqlite3_step(createStatement) == SQLITE_DONE else { sqlite3_finalize(createStatement); return }
                sqlite3_finalize(createStatement)
                guard let url = Bundle.module.url(forResource: "symbol", withExtension: "txt") else { return }
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
                let sourceLines: [String] = content.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)
                func insert(values: String) {
                        let command: String = "INSERT INTO symbol_table (category, unicode_version, code_point, cantonese, romanization, complexity, spell, spell_9key) VALUES \(values);"
                        var statement: OpaquePointer? = nil
                        defer { sqlite3_finalize(statement) }
                        guard sqlite3_prepare_v2(database, command, -1, &statement, nil) == SQLITE_OK else { return }
                        guard sqlite3_step(statement) == SQLITE_DONE else { return }
                }
                let range: Range<Int> = 0..<100
                let distance: Int = sourceLines.count / 100
                for number in range {
                        let bound: Int = (number == 99) ? sourceLines.count : ((number + 1) * distance)
                        let part = sourceLines[(number * distance)..<bound]
                        let entries = part.compactMap({ line -> String? in
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
                        let values: String = entries.joined(separator: ", ")
                        insert(values: values)
                }
        }
        private static func createEmojiSkinMapTable() async {
                let createTable: String = "CREATE TABLE emoji_skin_map (id INTEGER PRIMARY KEY AUTOINCREMENT, source TEXT NOT NULL, target TEXT NOT NULL);"
                var createStatement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, createTable, -1, &createStatement, nil) == SQLITE_OK else { sqlite3_finalize(createStatement); return }
                guard sqlite3_step(createStatement) == SQLITE_DONE else { sqlite3_finalize(createStatement); return }
                sqlite3_finalize(createStatement)
                guard let url = Bundle.module.url(forResource: "skin-tone-map", withExtension: "txt") else { return }
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
                let sourceLines: [String] = content.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)
                let entries = sourceLines.compactMap { line -> String? in
                        let parts = line.split(separator: "\t")
                        guard parts.count == 2 else { return nil }
                        let source = parts[0]
                        let target = parts[1]
                        return "('\(source)', '\(target)')"
                }
                let values: String = entries.joined(separator: ", ")
                let insert: String = "INSERT INTO emoji_skin_map (source, target) VALUES \(values);"
                var insertStatement: OpaquePointer? = nil
                defer { sqlite3_finalize(insertStatement) }
                guard sqlite3_prepare_v2(database, insert, -1, &insertStatement, nil) == SQLITE_OK else { return }
                guard sqlite3_step(insertStatement) == SQLITE_DONE else { return }
        }
        private static func createTextMarkTable() async {
                let createTable: String = "CREATE TABLE mark_table (id INTEGER PRIMARY KEY AUTOINCREMENT, input TEXT NOT NULL, mark TEXT NOT NULL, letter_count INTEGER NOT NULL, spell INTEGER NOT NULL, spell_9key INTEGER NOT NULL);"
                var createStatement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, createTable, -1, &createStatement, nil) == SQLITE_OK else { sqlite3_finalize(createStatement); return }
                guard sqlite3_step(createStatement) == SQLITE_DONE else { sqlite3_finalize(createStatement); return }
                sqlite3_finalize(createStatement)
                let sourceEntries: [TextMarkLexicon] = TextMarkLexicon.convert()
                func insert(values: String) {
                        let insert: String = "INSERT INTO mark_table (input, mark, letter_count, spell, spell_9key) VALUES \(values);"
                        var insertStatement: OpaquePointer? = nil
                        defer { sqlite3_finalize(insertStatement) }
                        guard sqlite3_prepare_v2(database, insert, -1, &insertStatement, nil) == SQLITE_OK else { return }
                        guard sqlite3_step(insertStatement) == SQLITE_DONE else { return }
                }
                let range: Range<Int> = 0..<200
                let distance: Int = sourceEntries.count / 200
                for number in range {
                        let bound: Int = (number == 199) ? sourceEntries.count : ((number + 1) * distance)
                        let part = sourceEntries[(number * distance)..<bound]
                        let entries = part.map({ entry -> String in
                                let escapedMark: String = entry.mark.contains(String.apostrophe) ? entry.mark.replacingOccurrences(of: "'", with: "''") : entry.mark
                                return "('\(entry.input)', '\(escapedMark)', \(entry.letterCount), \(entry.spellCode), \(entry.nineKeyCode))"
                        })
                        let values: String = entries.joined(separator: ", ")
                        insert(values: values)
                }
        }
        private static func createCoreSyllableTable() async {
                let createTable: String = "CREATE TABLE syllable_core_table (alias_code INTEGER PRIMARY KEY, origin_code INTEGER NOT NULL, alias TEXT NOT NULL, origin TEXT NOT NULL);"
                var createStatement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, createTable, -1, &createStatement, nil) == SQLITE_OK else { sqlite3_finalize(createStatement); return }
                guard sqlite3_step(createStatement) == SQLITE_DONE else { sqlite3_finalize(createStatement); return }
                sqlite3_finalize(createStatement)
                guard let url = Bundle.module.url(forResource: "syllable-core", withExtension: "txt") else { return }
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
                let sourceLines: [String] = content
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .components(separatedBy: .newlines)
                        .map({ $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: .controlCharacters) })
                        .filter(\.isNotEmpty)
                let entries = sourceLines.compactMap { line -> String? in
                        lazy var errorMessage: String = "syllable.txt : bad format : \(line)"
                        let parts = line.split(separator: "\t")
                        guard parts.count == 2 else { fatalError(errorMessage) }
                        let alias = parts[0]
                        let origin = parts[1]
                        let aliasCode = alias.serialCode
                        let originCode = origin.serialCode
                        return "(\(aliasCode), \(originCode), '\(alias)', '\(origin)')"
                }
                let values: String = entries.joined(separator: ", ")
                let insertValues: String = "INSERT INTO syllable_core_table (alias_code, origin_code, alias, origin) VALUES \(values);"
                var insertStatement: OpaquePointer? = nil
                defer { sqlite3_finalize(insertStatement) }
                guard sqlite3_prepare_v2(database, insertValues, -1, &insertStatement, nil) == SQLITE_OK else { return }
                guard sqlite3_step(insertStatement) == SQLITE_DONE else { return }
        }
        private static func createNineKeySyllableTable() async {
                let createTable: String = "CREATE TABLE syllable_9key_table (alias_code INTEGER PRIMARY KEY, origin_code INTEGER NOT NULL, alias_9key_code INTEGER NOT NULL, origin_9key_code INTEGER NOT NULL, alias TEXT NOT NULL, origin TEXT NOT NULL);"
                var createStatement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, createTable, -1, &createStatement, nil) == SQLITE_OK else { sqlite3_finalize(createStatement); return }
                guard sqlite3_step(createStatement) == SQLITE_DONE else { sqlite3_finalize(createStatement); return }
                sqlite3_finalize(createStatement)
                guard let url = Bundle.module.url(forResource: "syllable-9key", withExtension: "txt") else { fatalError("Failed to get URL of syllable-9key.txt") }
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { fatalError("Failed to read syllable-9key.txt") }
                let sourceLines: [String] = content
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .components(separatedBy: .newlines)
                        .map({ $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: .controlCharacters) })
                        .filter(\.isNotEmpty)
                let entries = sourceLines.compactMap { line -> String? in
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
                let values: String = entries.joined(separator: ", ")
                let insertValues: String = "INSERT INTO syllable_9key_table (alias_code, origin_code, alias_9key_code, origin_9key_code, alias, origin) VALUES \(values);"
                var insertStatement: OpaquePointer? = nil
                defer { sqlite3_finalize(insertStatement) }
                guard sqlite3_prepare_v2(database, insertValues, -1, &insertStatement, nil) == SQLITE_OK else { fatalError("Failed to prepare syllable-9key") }
                guard sqlite3_step(insertStatement) == SQLITE_DONE else { fatalError("Failed to step syllable-9key") }
        }
        private static func createPinyinSyllableTable() async {
                let createTable: String = "CREATE TABLE syllable_pinyin_table (code INTEGER PRIMARY KEY, code_9key INTEGER NOT NULL, syllable TEXT NOT NULL);"
                var createStatement: OpaquePointer? = nil
                guard sqlite3_prepare_v2(database, createTable, -1, &createStatement, nil) == SQLITE_OK else { sqlite3_finalize(createStatement); return }
                guard sqlite3_step(createStatement) == SQLITE_DONE else { sqlite3_finalize(createStatement); return }
                sqlite3_finalize(createStatement)
                guard let url = Bundle.module.url(forResource: "syllable-pinyin", withExtension: "txt") else { return }
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
                let sourceLines: [String] = content
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .components(separatedBy: .newlines)
                        .map({ $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: .controlCharacters) })
                        .filter(\.isNotEmpty)
                let entries = sourceLines.compactMap { syllable -> String? in
                        lazy var errorMessage: String = "syllable-pinyin.txt : bad format : \(syllable)"
                        return "(\(syllable.serialCode), \(syllable.keypadCode), '\(syllable)')"
                }
                let values: String = entries.joined(separator: ", ")
                let insertValues: String = "INSERT INTO syllable_pinyin_table (code, code_9key, syllable) VALUES \(values);"
                var insertStatement: OpaquePointer? = nil
                defer { sqlite3_finalize(insertStatement) }
                guard sqlite3_prepare_v2(database, insertValues, -1, &insertStatement, nil) == SQLITE_OK else { return }
                guard sqlite3_step(insertStatement) == SQLITE_DONE else { return }
        }
}
