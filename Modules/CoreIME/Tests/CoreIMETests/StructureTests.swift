import Testing
@testable import CoreIME

@Suite("Character structure lookup")
struct StructureTests {

        init() {
                prepareTestDatabase()
        }

        @Test("component romanizations return the composed character")
        func basicLookup() {
                let keys = inputKeys("mukmuk")
                let items = Engine.structureReverseLookup(keys, segmentation: Segmenter.segment(keys))

                #expect(items.contains(where: { $0.text == "林" && $0.input == "mukmuk" }))
        }

        @Test("tone and separator filters preserve valid component boundaries")
        func filtering() {
                let toned = inputKeys("mukqqmukqq")
                let separated = inputKeys("muk'muk")

                #expect(Engine.structureReverseLookup(toned, segmentation: Segmenter.segment(toned)).contains(where: { $0.text == "林" }))
                #expect(Engine.structureReverseLookup(separated, segmentation: Segmenter.segment(separated)).contains(where: { $0.text == "林" }))
                #expect(Engine.structureReverseLookup(inputKeys("zzzz"), segmentation: []).isEmpty)
        }

        @Test("structure lookup covers tone placement and count variants")
        func toneVariants() {
                let leadingTone = inputKeys("mukqqmuk")
                let trailingTone = inputKeys("mukmukqq")
                let separatorLeadingTone = inputKeys("mukqq'muk")
                let separatorTrailingTone = inputKeys("muk'mukqq")
                let tooManySeparatorTones = inputKeys("mukqq'mukqq")
                let tooManyTones = inputKeys("mukqqmukqqqq")

                #expect(Engine.structureReverseLookup(leadingTone, segmentation: Segmenter.segment(leadingTone)).contains(where: { $0.text == "林" }))
                #expect(Engine.structureReverseLookup(trailingTone, segmentation: Segmenter.segment(trailingTone)).contains(where: { $0.text == "林" }))
                #expect(Engine.structureReverseLookup(separatorLeadingTone, segmentation: Segmenter.segment(separatorLeadingTone)).contains(where: { $0.text == "林" }))
                #expect(Engine.structureReverseLookup(separatorTrailingTone, segmentation: Segmenter.segment(separatorTrailingTone)).contains(where: { $0.text == "林" }))
                #expect(Engine.structureReverseLookup(tooManySeparatorTones, segmentation: Segmenter.segment(tooManySeparatorTones)).isEmpty)
                #expect(Engine.structureReverseLookup(tooManyTones, segmentation: Segmenter.segment(tooManyTones)).isEmpty)
        }
}
