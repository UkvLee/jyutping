import Testing
@testable import CommonExtensions

@Suite("Character codes")
struct CharCodeTests {

        @Test("string protocols encode lowercase letters and skip unsupported characters")
        func stringProtocolCodes() {
                let substring = "012abcXYZ".dropFirst(3)

                #expect("abc".serialCode == 202122)
                #expect("adgjmptw".keypadCode == 23456789)
                #expect("a-b C!".serialCode == 2021)
                #expect("a-b C!".keypadCode == 22)
                #expect(substring.serialCode == 202122)
                #expect(substring.keypadCode == 222)
                #expect("".serialCode == 0)
                #expect("".keypadCode == 0)
        }

        @Test("character collections use the same codes as strings")
        func characterCollectionCodes() {
                let characters = Array("abcdefghijklmnopqrstuvwxyz")
                let slice = characters[23...]

                #expect(characters.serialCode == "abcdefghijklmnopqrstuvwxyz".serialCode)
                #expect(Array("abc").keypadCode == 222)
                #expect(Array("def").keypadCode == 333)
                #expect(Array("ghi").keypadCode == 444)
                #expect(Array("jkl").keypadCode == 555)
                #expect(Array("mno").keypadCode == 666)
                #expect(Array("pqrs").keypadCode == 7777)
                #expect(Array("tuv").keypadCode == 888)
                #expect(Array("wxyz").keypadCode == 9999)
                #expect(slice.serialCode == 434445)
                #expect(slice.keypadCode == 999)
                #expect(Array<Character>().serialCode == 0)
                #expect(Array<Character>().keypadCode == 0)
        }
}
