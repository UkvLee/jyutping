import Testing
@testable import CoreIME

func inputKeys(_ text: String) -> [VirtualInputKey] {
        return text.compactMap({ character in
                switch character {
                case "'": VirtualInputKey.apostrophe
                case "`": VirtualInputKey.grave
                default: VirtualInputKey.matchInputKey(for: character)
                }
        })
}

func inputEvents(_ text: String, case keyboardCase: KeyboardCase = .lowercased) -> [BasicInputEvent] {
        return inputKeys(text).map({ BasicInputEvent(key: $0, case: keyboardCase) })
}

func inputCombos(_ digits: [Int]) -> [Combo] {
        return digits.compactMap(Combo.init(rawValue:))
}

func expectSegmentationOrder<S: RandomAccessCollection>(_ schemes: S, length: (S.Element) -> Int, count: (S.Element) -> Int) {
        #expect(schemes.isEmpty == false)
        let ordered = zip(schemes, schemes.dropFirst()).allSatisfy({ lhs, rhs in
                length(lhs) > length(rhs) || (length(lhs) == length(rhs) && count(lhs) <= count(rhs))
        })
        #expect(ordered)
}
