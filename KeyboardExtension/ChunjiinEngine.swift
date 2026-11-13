import Foundation

/// 문서에 적용할 변경: 뒤에서 `deleteCount`글자를 지우고 `insert`를 넣는다.
struct TextEdit {
    var deleteCount: Int
    var insert: String
    var isEmpty: Bool { deleteCount == 0 && insert.isEmpty }
}

/// 갤럭시 천지인 방식 한글 조합기.
/// - 자음 키는 연타로 순환 (ㄱ→ㅋ→ㄲ). 연타 간격(`multitapTimeout`)이 지나면 같은 키도 새 글자.
/// - 모음은 ㅣ · ㅡ 세 획을 조합.
/// - 키 입력마다 "지금 조합 중인 글자"를 다시 그려서 TextEdit으로 돌려준다.
final class ChunjiinEngine {

    // MARK: - 자모 표

    static let dot: Character = "ㆍ"
    static let doubleDot: Character = "ᆢ"
    static let i: Character = "ㅣ"
    static let eu: Character = "ㅡ"

    private static let cho = Array("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")
    private static let jung = Array("ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ")
    private static let jong: [Character?] = [nil] + Array("ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ").map { Optional($0) }

    private static let compound: [String: Character] = [
        "ㄱㅅ": "ㄳ", "ㄴㅈ": "ㄵ", "ㄴㅎ": "ㄶ", "ㄹㄱ": "ㄺ", "ㄹㅁ": "ㄻ", "ㄹㅂ": "ㄼ",
        "ㄹㅅ": "ㄽ", "ㄹㅌ": "ㄾ", "ㄹㅍ": "ㄿ", "ㄹㅎ": "ㅀ", "ㅂㅅ": "ㅄ",
    ]

    /// 현재 모음 상태 + 획 → 다음 모음 상태. 키 ""는 모음이 없을 때.
    private static let vowelTable: [String: [Character: Character]] = [
        "": ["ㅣ": "ㅣ", "ㆍ": "ㆍ", "ㅡ": "ㅡ"],
        "ㆍ": ["ㅣ": "ㅓ", "ㆍ": "ᆢ", "ㅡ": "ㅗ"],
        "ᆢ": ["ㅣ": "ㅕ", "ㆍ": "ㆍ", "ㅡ": "ㅛ"],
        "ㅣ": ["ㆍ": "ㅏ"],
        "ㅏ": ["ㆍ": "ㅑ", "ㅣ": "ㅐ"],
        "ㅑ": ["ㅣ": "ㅒ"],
        "ㅓ": ["ㅣ": "ㅔ"],
        "ㅕ": ["ㅣ": "ㅖ"],
        "ㅡ": ["ㆍ": "ㅜ", "ㅣ": "ㅢ"],
        "ㅜ": ["ㆍ": "ㅠ", "ㅣ": "ㅟ"],
        "ㅠ": ["ㅣ": "ㅝ"],
        "ㅝ": ["ㅣ": "ㅞ"],
        "ㅗ": ["ㅣ": "ㅚ"],
        "ㅚ": ["ㆍ": "ㅘ"],
        "ㅘ": ["ㅣ": "ㅙ"],
    ]

    private static func isRealVowel(_ c: Character?) -> Bool {
        guard let c else { return false }
        return jung.contains(c)
    }

    private static func combine(_ v: Character?, _ stroke: Character) -> Character? {
        vowelTable[v.map { String($0) } ?? ""]?[stroke]
    }

    // MARK: - 조합 중인 음절

    private struct Syllable {
        var cho: Character?
        var jung: Character?      // ㆍ, ᆢ 같은 미완성 모음도 들어감
        var jong: Character?
        var jong2: Character?     // 겹받침 두 번째
        var pending: Character?   // 받침 뒤에 찍은 ㆍ/ᆢ (다음 획에 따라 받침이 넘어감)

        var isEmpty: Bool { cho == nil && jung == nil }

        func render() -> String {
            if let cho, let jung, ChunjiinEngine.isRealVowel(jung),
               let ci = ChunjiinEngine.cho.firstIndex(of: cho),
               let vi = ChunjiinEngine.jung.firstIndex(of: jung) {
                var jongChar: Character? = jong
                if let j1 = jong, let j2 = jong2 {
                    jongChar = ChunjiinEngine.compound["\(j1)\(j2)"]
                }
                let ji = ChunjiinEngine.jong.firstIndex(of: jongChar) ?? 0
                let code = 0xAC00 + (ci * 21 + vi) * 28 + ji
                var s = String(Character(UnicodeScalar(code)!))
                if let pending { s.append(pending) }
                return s
            }
            var s = ""
            if let cho { s.append(cho) }
            if let jung { s.append(jung) }
            return s
        }
    }

    // MARK: - 상태

    /// 연타 허용 간격(초). 삼성 키보드의 "연속 키누름 간격"과 같은 역할.
    var multitapTimeout: TimeInterval = 0.8

    private var current = Syllable()
    /// 이번 키 입력으로 확정된 앞 글자(아직 화면에서 다시 그릴 수 있는 범위).
    private var prefix = ""
    private var lastKey: String?
    private var lastConsonant: Character?
    private var lastTime: Date = .distantPast
    private var snapshot: Syllable?

    /// 지금 문서에 "조합 중"으로 올라가 있는 글자.
    var display: String { prefix + current.render() }
    var isComposing: Bool { !current.isEmpty }

    private var multitapAlive: Bool {
        lastKey != nil && Date().timeIntervalSince(lastTime) <= multitapTimeout
    }

    // MARK: - 입력

    /// 자음 키. `key`는 키 식별자, `cycle`은 연타 순서 (예: ["ㄱ","ㅋ","ㄲ"]).
    func inputConsonant(key: String, cycle: [Character]) -> TextEdit {
        let old: String
        let c: Character
        if lastKey == key, let snap = snapshot, multitapAlive,
           let last = lastConsonant, let idx = cycle.firstIndex(of: last) {
            old = display
            current = snap
            prefix = ""
            c = cycle[(idx + 1) % cycle.count]
        } else {
            prefix = ""
            old = display
            snapshot = current
            c = cycle[0]
        }
        putConsonant(c)
        lastKey = key
        lastConsonant = c
        lastTime = Date()
        return diff(old, display)
    }

    /// 모음 획: ㅣ, ㆍ, ㅡ
    func inputVowel(_ stroke: Character) -> TextEdit {
        prefix = ""
        let old = display
        resetMultitap()

        if let pending = current.pending {
            let v = Self.combine(pending, stroke)
            if Self.isRealVowel(v) {
                moveJong(withVowel: v!)
            } else if let v {
                current.pending = v
            } else {
                commitCurrent()
                current.jung = Self.combine(nil, stroke)
            }
        } else if current.jong != nil {
            if stroke == Self.dot {
                current.pending = Self.dot
            } else {
                moveJong(withVowel: Self.combine(nil, stroke)!)
            }
        } else if current.jung != nil {
            if let v = Self.combine(current.jung, stroke) {
                current.jung = v
            } else {
                commitCurrent()
                current.jung = Self.combine(nil, stroke)
            }
        } else {
            current.jung = Self.combine(nil, stroke)
        }
        return diff(old, display)
    }

    /// 조합 중이면 자모 하나를 지우고 TextEdit을 돌려준다. 조합 중이 아니면 nil (호출 쪽에서 그냥 지움).
    func backspace() -> TextEdit? {
        prefix = ""
        resetMultitap()
        guard !current.isEmpty else { return nil }
        let old = display
        if current.pending != nil { current.pending = nil }
        else if current.jong2 != nil { current.jong2 = nil }
        else if current.jong != nil { current.jong = nil }
        else if current.jung != nil { current.jung = nil }
        else { current.cho = nil }
        return diff(old, display)
    }

    /// 스페이스. true면 "연타만 끊고 공백은 넣지 않음".
    func spaceShouldOnlyBreak() -> Bool {
        let breakOnly = multitapAlive && !current.isEmpty
        finish()
        return breakOnly
    }

    /// 조합을 끝낸다(문서 내용은 그대로 둠).
    func finish() {
        current = Syllable()
        prefix = ""
        snapshot = nil
        resetMultitap()
    }

    // MARK: - 내부

    private func resetMultitap() {
        lastKey = nil
        lastConsonant = nil
        snapshot = nil
    }

    private func commitCurrent() {
        prefix += current.render()
        current = Syllable()
    }

    private func putConsonant(_ c: Character) {
        let s = current
        // 초성 자리가 새로 필요한 경우: 비어 있음/모음 미완성/모음만 있음/받침 뒤 ㆍ
        if s.pending != nil || !Self.isRealVowel(s.jung) || s.cho == nil {
            if !s.isEmpty { commitCurrent() }
            current.cho = c
            return
        }
        if s.jong == nil {
            if Self.jong.contains(c) {
                current.jong = c
                return
            }
        } else if s.jong2 == nil, Self.compound["\(s.jong!)\(c)"] != nil {
            current.jong2 = c
            return
        }
        commitCurrent()
        current.cho = c
    }

    /// 받침(겹받침이면 뒤쪽)을 떼어서 다음 음절의 초성으로 넘긴다.
    private func moveJong(withVowel v: Character) {
        let moved: Character
        if let j2 = current.jong2 {
            moved = j2
            current.jong2 = nil
        } else {
            moved = current.jong!
            current.jong = nil
        }
        current.pending = nil
        prefix += current.render()
        current = Syllable(cho: moved, jung: v)
    }

    private func diff(_ old: String, _ new: String) -> TextEdit {
        let o = Array(old), n = Array(new)
        var common = 0
        while common < o.count, common < n.count, o[common] == n[common] { common += 1 }
        return TextEdit(deleteCount: o.count - common, insert: String(n[common...]))
    }
}
