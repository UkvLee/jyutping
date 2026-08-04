import Testing
@testable import CoreIME

@Suite("Jyutping engine")
struct EngineTests {

        @Test("prepare initializes the packaged database and segmenters")
        func prepare() {
                Engine.prepare()
                #expect(Segmenter.segment(inputKeys("ngo")).isNotEmpty)
                #expect(NineKeySegmenter.segment(inputCombos([6, 4, 6])).isNotEmpty)
        }

        @Test("empty and single-key suggestions follow specialized paths")
        func emptyAndSingleKeys() {
                #expect(Engine.suggest([VirtualInputKey](), segmentation: []).isEmpty)

                let aa = Engine.suggest([.letterA], segmentation: Segmenter.segment([.letterA]))
                let o = Engine.suggest([.letterO], segmentation: Segmenter.segment([.letterO]))
                let m = Engine.suggest([.letterM], segmentation: Segmenter.segment([.letterM]))
                let n = Engine.suggest([.letterN], segmentation: Segmenter.segment([.letterN]))

                #expect(aa.contains(where: { $0.text == "啊" && $0.romanization == "aa3" }))
                #expect(o.contains(where: { $0.romanization == "o1" }))
                #expect(m.contains(where: { $0.text == "唔" && $0.romanization == "m4" }))
                #expect(n.isNotEmpty)
        }

        @Test("full syllable suggestions preserve romanization input and mark")
        func fullSyllable() {
                let keys = inputKeys("ngo")
                let suggestions = Engine.suggest(keys, segmentation: Segmenter.segment(keys))
                let item = suggestions.first(where: { $0.text == "我" && $0.romanization == "ngo5" })

                #expect(item?.input == "ngo")
                #expect(item?.mark == "ngo")
        }

        @Test("deep search returns prefixes while shallow search limits fallback work")
        func deepSearch() {
                let keys = inputKeys("ngoz")
                let segmentation = Segmenter.segment(keys)
                let deep = Engine.suggest(keys, segmentation: segmentation)
                let shallow = Engine.suggest(keys, segmentation: segmentation, deepSearch: false)

                #expect(deep.contains(where: { $0.text == "我" }))
                #expect(deep.count >= shallow.count)
        }

        @Test("tone letters and digits filter readings and rewrite consumed input")
        func tones() {
                let toneLetterKeys = inputKeys("ngoxx")
                let toneDigitKeys = inputKeys("ngo5")
                let toneLetterSuggestions = Engine.suggest(toneLetterKeys, segmentation: Segmenter.segment(toneLetterKeys))
                let toneDigitSuggestions = Engine.suggest(toneDigitKeys, segmentation: Segmenter.segment(toneDigitKeys))

                #expect(toneLetterSuggestions.contains(where: { $0.text == "我" && $0.romanization == "ngo5" && $0.input == "ngoxx" }))
                #expect(toneLetterSuggestions.contains(where: { $0.romanization == "ngo4" }) == false)
                #expect(toneDigitSuggestions.contains(where: { $0.text == "我" && $0.input == "ngo5" }))
        }

        @Test("tone filtering covers multi-syllable tone positions")
        func tonePositions() {
                let inputs = [
                        "nei5hou",
                        "neihou2",
                        "nei5hou2",
                        "nei5hou2a",
                        "ngo55",
                        "nei5hou2aa3"
                ]

                for input in inputs {
                        let keys = inputKeys(input)
                        let suggestions = Engine.suggest(keys, segmentation: Segmenter.segment(keys))
                        #expect(suggestions.allSatisfy({ $0.input.isNotEmpty }))
                }
        }

        @Test("separators require valid syllable boundaries")
        func separators() {
                let separated = inputKeys("nei'hou")
                let trailing = inputKeys("ngo'")
                let heading = inputKeys("'ngo")

                #expect(Engine.suggest(separated, segmentation: Segmenter.segment(separated)).contains(where: { $0.text == "你好" && $0.input == "nei'hou" }))
                #expect(Engine.suggest(trailing, segmentation: Segmenter.segment(trailing)).contains(where: { $0.text == "我" && $0.input == "ngo'" }))
                #expect(Engine.suggest(heading, segmentation: Segmenter.segment(heading)).isEmpty)
        }

        @Test("separator filtering covers partial and repeated boundaries")
        func separatorVariants() {
                let inputs = [
                        "n'h",
                        "n'h'",
                        "n'e'i",
                        "nei'hou'",
                        "n'e'i'h"
                ]

                for input in inputs {
                        let keys = inputKeys(input)
                        _ = Engine.suggest(keys, segmentation: Segmenter.segment(keys))
                }
        }

        @Test("combined separator and tone input keeps matching romanization prefixes")
        func separatorsAndTones() {
                let keys = inputKeys("nei5'hou2")
                let suggestions = Engine.suggest(keys, segmentation: Segmenter.segment(keys))

                #expect(suggestions.contains(where: { $0.text == "你" && $0.romanization == "nei5" && $0.input == "nei5'hou2" }))
                #expect(suggestions.allSatisfy({ "nei5'hou2".hasPrefix($0.romanization) }))
        }

        @Test("multiple syllables can produce concatenated fallback candidates")
        func concatenation() {
                let keys = inputKeys("ngomuk")
                let suggestions = Engine.suggest(keys, segmentation: Segmenter.segment(keys))

                #expect(suggestions.contains(where: { $0.text == "我木" && $0.isCompound }))
        }

        @Test("cancelled suggestions stop before querying")
        func cancelledSuggestions() async {
                let keys = inputKeys(String(repeating: "ngaam", count: 5))
                let segmentation = Segmenter.segment(keys)
                let task = Task { () -> [Lexicon] in
                        withUnsafeCurrentTask(body: { $0?.cancel() })
                        return Engine.suggest(keys, segmentation: segmentation)
                }

                #expect(await task.value.isEmpty)
        }
}
