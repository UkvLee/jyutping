import Testing
@testable import CoreIME

@Suite("Extra entries")
struct ExtraEntryTests {

        init() {
                prepareTestDatabase()
        }

        @Test("serial lookup returns the matching entry and metadata")
        func serialLookup() {
                let suggestions = ExtraEntry.search(keys: inputKeys("bi"))
                let item = suggestions.first(where: { $0.text == "啤" && $0.romanization == "bi1" })

                #expect(item?.input == "bi")
                #expect(item?.mark == "bi")
        }

        @Test("nine-key lookup returns the matching entry and metadata")
        func nineKeyLookup() {
                let suggestions = ExtraEntry.nineKeySearch(combos: inputCombos([2, 4]))
                let item = suggestions.first(where: { $0.text == "啤" && $0.romanization == "bi1" })

                #expect(item?.input == "bi")
                #expect(item?.mark == "bi")
        }

        @Test("lookups require both the encoded value and its letter count")
        func exactLength() {
                #expect(ExtraEntry.search(keys: inputKeys("b")).isEmpty)
                #expect(ExtraEntry.nineKeySearch(combos: inputCombos([2])).isEmpty)
                #expect(ExtraEntry.search(keys: inputKeys("bii")).isEmpty)
                #expect(ExtraEntry.nineKeySearch(combos: inputCombos([2, 4, 4])).isEmpty)
        }

        @Test("engines include extra entries when the database has no ideal match")
        func engineFallbacks() async {
                let keys = inputKeys("bi")
                let combos = inputCombos([2, 4])
                let serialSuggestions = Engine.suggest(keys, segmentation: Segmenter.segment(keys))
                let nineKeySuggestions = await NineKeyEngine.suggest(combos: combos, segmentation: NineKeySegmenter.segment(combos))

                #expect(serialSuggestions.contains(where: { $0.text == "啤" && $0.romanization == "bi1" }))
                #expect(nineKeySuggestions.contains(where: { $0.text == "啤" && $0.romanization == "bi1" }))
        }
}
