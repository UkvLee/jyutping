import Testing
@testable import CoreIME

@Suite("Input events")
struct InputEventTests {

        @Test("basic input events preserve keys and keyboard cases")
        func basicInputEvents() {
                let lowercased = BasicInputEvent(key: .letterA, case: .lowercased)
                let uppercased = BasicInputEvent(key: .letterB, isCapitalized: true)
                let inferredLowercase = BasicInputEvent(key: .letterC, isCapitalized: false)

                #expect(lowercased.key == .letterA)
                #expect(lowercased.case == .lowercased)
                #expect(lowercased.isCapitalized == false)
                #expect(uppercased.case == .uppercased)
                #expect(uppercased.isCapitalized)
                #expect(inferredLowercase.case == .lowercased)
        }

        @Test("ambiguous events transform only nonempty key sets")
        func ambiguousEvents() {
                let events = [
                        AmbiguousInputEvent(keys: [.letterA], case: .uppercased),
                        AmbiguousInputEvent(keys: [], case: .lowercased),
                        AmbiguousInputEvent(keys: [.number1], case: .capsLocked)
                ]
                let transformed = events.basicTransformed()

                #expect(transformed.count == 2)
                #expect(transformed[0] == BasicInputEvent(key: .letterA, case: .uppercased))
                #expect(transformed[1] == BasicInputEvent(key: .number1, case: .capsLocked))
        }

        @Test("preview marks normalize tone keys and pairs")
        func previewToneKeys() {
                #expect(inputEvents("gwongvxqvvxxqq").normalizedPreviewMark() == "gwong1 2 3 4 5 6")
                #expect(inputEvents("vvvxxxqqq").normalizedPreviewMark() == "4 1 5 2 6 3")
        }

        @Test("preview marks preserve capitalization and space nonletters")
        func previewCapitalizationAndSpacing() {
                let events: [BasicInputEvent] = [
                        .init(key: .letterN, case: .uppercased),
                        .init(key: .letterG, case: .lowercased),
                        .init(key: .number5, case: .lowercased),
                        .init(key: .apostrophe, case: .lowercased),
                        .init(key: .letterA, case: .lowercased),
                        .init(key: .letterA, case: .lowercased),
                        .init(key: .number3, case: .lowercased)
                ]

                #expect(events.normalizedPreviewMark() == "Ng5 ' aa3")
                #expect([BasicInputEvent]().normalizedPreviewMark().isEmpty)
        }
}
