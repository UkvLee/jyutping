extension StringProtocol {

        /// Encodes lowercase Basic Latin letters as two-digit serial codes.
        public var serialCode: Int {
                return compactMap(\.interCode).radix100Overflowed()
        }

        /// Encodes lowercase Basic Latin letters as telephone keypad digits.
        public var keypadCode: Int {
                return compactMap(\.keypadCharCode).decimalOverflowed()
        }
}

extension RandomAccessCollection where Element == Character {

        /// Encodes lowercase Basic Latin letters as two-digit serial codes.
        public var serialCode: Int {
                return compactMap(\.interCode).radix100Overflowed()
        }

        /// Encodes lowercase Basic Latin letters as telephone keypad digits.
        public var keypadCode: Int {
                return compactMap(\.keypadCharCode).decimalOverflowed()
        }
}

private extension Character {

        var interCode: Int? {
                return Self.codeMap[self]
        }

        static let codeMap: [Character : Int] = [
                "a" : 20,
                "b" : 21,
                "c" : 22,
                "d" : 23,
                "e" : 24,
                "f" : 25,
                "g" : 26,
                "h" : 27,
                "i" : 28,
                "j" : 29,
                "k" : 30,
                "l" : 31,
                "m" : 32,
                "n" : 33,
                "o" : 34,
                "p" : 35,
                "q" : 36,
                "r" : 37,
                "s" : 38,
                "t" : 39,
                "u" : 40,
                "v" : 41,
                "w" : 42,
                "x" : 43,
                "y" : 44,
                "z" : 45,
        ]

        var keypadCharCode: Int? {
                return Self.keypadCodeMap[self]
        }

        static let keypadCodeMap: [Character : Int] = [
                "a" : 2,
                "b" : 2,
                "c" : 2,
                "d" : 3,
                "e" : 3,
                "f" : 3,
                "g" : 4,
                "h" : 4,
                "i" : 4,
                "j" : 5,
                "k" : 5,
                "l" : 5,
                "m" : 6,
                "n" : 6,
                "o" : 6,
                "p" : 7,
                "q" : 7,
                "r" : 7,
                "s" : 7,
                "t" : 8,
                "u" : 8,
                "v" : 8,
                "w" : 9,
                "x" : 9,
                "y" : 9,
                "z" : 9,
        ]
}
