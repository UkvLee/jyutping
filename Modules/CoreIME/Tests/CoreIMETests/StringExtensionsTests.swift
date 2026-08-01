import Testing
@testable import CoreIME

@Suite("CoreIME string extensions")
struct StringExtensionsTests {

        @Test("tone conversion maps single and paired tone letters")
        func toneConversion() {
                #expect("gwongv".toneConverted() == "gwong1")
                #expect("gwongx".toneConverted() == "gwong2")
                #expect("gwongq".toneConverted() == "gwong3")
                #expect("gwongvv".toneConverted() == "gwong4")
                #expect("gwongxx".toneConverted() == "gwong5")
                #expect("gwongqq".toneConverted() == "gwong6")
                #expect("vxqvvxxqq".toneConverted() == "123456")
                #expect("vvvxxxqqq".toneConverted() == "415263")
                #expect("abc".toneConverted() == "abc")
                #expect("".toneConverted() == "")
        }

        @Test("mark formatting spaces nonletters")
        func markFormatting() {
                #expect("gwong2".markFormatted() == "gwong2 ")
                #expect("ngo5'aa3".markFormatted() == "ngo5 ' aa3 ")
                #expect("AaZz".markFormatted() == "AaZz")
                #expect("".markFormatted() == "")
        }
}
