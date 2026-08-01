import Testing
@testable import CoreIME

@Suite("Character standards")
struct CharacterStandardTests {

        @Test("raw-value matching falls back to the preset standard")
        func matching() {
                for standard in CharacterStandard.allCases {
                        #expect(CharacterStandard.standard(of: standard.rawValue) == standard)
                }
                #expect(CharacterStandard.standard(of: -1) == .preset)
        }

        @Test("traditional and simplified predicates are complementary")
        func predicates() {
                #expect(CharacterStandard.mutilated.isMutilated)
                #expect(CharacterStandard.mutilated.isTraditional == false)
                #expect(CharacterStandard.preset.isMutilated == false)
                #expect(CharacterStandard.preset.isTraditional)
        }

        @Test("Cangjie variants match raw values and default to Cangjie 5")
        func CangjieVariants() {
                for variant in CangjieVariant.allCases {
                        #expect(CangjieVariant.variant(of: variant.rawValue) == variant)
                }
                #expect(CangjieVariant.variant(of: -1) == .cangjie5)
        }
}
