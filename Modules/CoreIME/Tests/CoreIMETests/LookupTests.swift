import Testing
@testable import CoreIME

@Suite("Romanization lookup")
struct LookupTests {

        @Test("lookup returns exact and composed romanizations")
        func lookup() {
                #expect(Engine.lookup("我") == ["ngo5"])
                #expect(Engine.lookup("你好").contains("nei5 hou2"))
                #expect(Engine.lookup("我木") == ["ngo5 muk6"])
                #expect(Engine.lookup("").isEmpty)
                #expect(Engine.lookup("𠀀").isEmpty)
                #expect(Engine.lookup("我𠀀").isEmpty)
        }

        @Test("reverse lookup builds lexicons with caller display metadata")
        func reverseLookup() {
                let items = Engine.reveresLookup(text: "我", input: "wo", mark: "w o")

                #expect(items == [Lexicon(text: "我", romanization: "ngo5", input: "wo", mark: "w o")])
                #expect(Engine.reveresLookup(text: "𠀀", input: "x").isEmpty)
        }
}
