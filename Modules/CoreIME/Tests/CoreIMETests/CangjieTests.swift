import Testing
@testable import CoreIME

@Suite("Cangjie and Quick lookup")
struct CangjieTests {

        @Test("all Cangjie variants return exact and prefix matches")
        func variants() {
                let cases: [(CangjieVariant, String, String)] = [
                        (.cangjie5, "hqi", "我"),
                        (.cangjie3, "hqi", "我"),
                        (.quick5, "hi", "我"),
                        (.quick3, "hi", "我")
                ]

                for (variant, input, expectedText) in cases {
                        let exact = Engine.cangjieReverseLookup(keys: inputKeys(input), variant: variant)
                        let prefix = Engine.cangjieReverseLookup(keys: inputKeys(String(input.prefix(1))), variant: variant)
                        #expect(exact.contains(where: { $0.text == expectedText && $0.input == input }))
                        #expect(prefix.isNotEmpty)
                }
        }

        @Test("unmatched Cangjie input returns no reverse lookup")
        func unmatched() {
                for variant in CangjieVariant.allCases {
                        #expect(Engine.cangjieReverseLookup(keys: inputKeys("zzzzz"), variant: variant).isEmpty)
                }
        }
}
