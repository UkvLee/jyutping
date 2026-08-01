import CommonExtensions

struct LexiconEntry: Hashable {

        /// Chinese text
        let word: String

        /// Jyutping, Pinyin, etc.
        let romanization: String

        /// Element/character count of the `word`
        let charCount: Int

        /// Length of the letter-only romanization (no tones & no spaces)
        let letterCount: Int

        /// Conjoined digit of letter-only-syllable (phone) lengths.
        ///
        /// For example: phone lengths of romanization “gwong2 dung1 dou6” are `[5, 4, 3]`, which makes the `complexity` become `543`
        let complexity: Int

        /// Conjoined code of initials/anchors
        let anchors: Int

        /// Conjoined code of the letter-only romanization (no tones & no spaces)
        let spell: Int

        /// Conjoined keypad code of initials/anchors
        let nineKeyAnchors: Int

        /// Conjoined keypad code of the letter-only romanization (no tones & no spaces)
        let nineKeySpell: Int

        /// Create a lexicon entry
        /// - Parameters:
        ///   - word: Chinese text
        ///   - romanization: Jyutping, Pinyin, etc.
        ///   - letterCount: Length of the letter-only romanization (no tones & no spaces)
        ///   - complexity: Conjoined digit of letter-only-syllable (phone) lengths.
        ///   - anchors: Conjoined code of initials/anchors
        ///   - spell: Conjoined code of the letter-only romanization (no tones & no spaces)
        ///   - nineKeyAnchors: Conjoined keypad code of initials/anchors
        ///   - nineKeySpell: Conjoined keypad code of the letter-only romanization (no tones & no spaces)
        init(word: String, romanization: String, letterCount: Int, complexity: Int, anchors: Int, spell: Int, nineKeyAnchors: Int, nineKeySpell: Int) {
                self.word = word
                self.romanization = romanization
                self.charCount = word.count
                self.letterCount = letterCount
                self.complexity = complexity
                self.anchors = anchors
                self.spell = spell
                self.nineKeyAnchors = nineKeyAnchors
                self.nineKeySpell = nineKeySpell
        }

        // Equatable
        static func ==(lhs: LexiconEntry, rhs: LexiconEntry) -> Bool {
                return lhs.word == rhs.word && lhs.romanization == rhs.romanization
        }

        // Hashable
        func hash(into hasher: inout Hasher) {
                hasher.combine(word)
                hasher.combine(romanization)
        }
}
