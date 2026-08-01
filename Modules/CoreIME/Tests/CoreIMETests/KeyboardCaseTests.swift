import Testing
@testable import CoreIME

@Suite("Keyboard cases")
struct KeyboardCaseTests {

        @Test("case predicates identify each keyboard state")
        func predicates() {
                #expect(KeyboardCase.lowercased.isLowercased)
                #expect(KeyboardCase.lowercased.isUppercased == false)
                #expect(KeyboardCase.lowercased.isCapsLocked == false)
                #expect(KeyboardCase.lowercased.isCapitalized == false)
                #expect(KeyboardCase.uppercased.isUppercased)
                #expect(KeyboardCase.uppercased.isCapitalized)
                #expect(KeyboardCase.capsLocked.isCapsLocked)
                #expect(KeyboardCase.capsLocked.isCapitalized)
        }
}
