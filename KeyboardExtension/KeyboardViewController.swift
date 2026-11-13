import UIKit
import AudioToolbox

/// 키들을 가중치대로 가로로 배치하는 줄
final class RowView: UIView {
    private var weights: [CGFloat] = []
    func add(_ v: UIView, weight: CGFloat = 1) {
        addSubview(v)
        weights.append(weight)
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let total = weights.reduce(0, +)
        guard total > 0 else { return }
        var x: CGFloat = 0
        for (v, w) in zip(subviews, weights) {
            let width = bounds.width * w / total
            v.frame = CGRect(x: x, y: 0, width: width, height: bounds.height)
            x += width
        }
    }
}

/// 줄들을 같은 높이로 세로 배치
final class RowsView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        let h = bounds.height / CGFloat(max(subviews.count, 1))
        for (i, v) in subviews.enumerated() {
            v.frame = CGRect(x: 0, y: CGFloat(i) * h, width: bounds.width, height: h)
        }
    }
}

final class KeyboardViewController: UIInputViewController {

    private enum Mode { case korean, english, symbols, emoji }
    private enum Shift { case off, once, locked }

    // MARK: 설정값

    /// 키보드 높이 (아래 마이크/지구본 줄 제외)
    private let keyboardHeight: CGFloat = 228
    /// 키 누를 때 진동 / 소리 (둘 다 '전체 접근 허용'을 켜야 동작)
    private let enableHaptic = true
    private let enableSound = false
    // 스페이스 드래그 감도는 KeyView.dragStep, 연타 간격은 ChunjiinEngine.multitapTimeout

    // MARK: 상태

    private let engine = ChunjiinEngine()
    private var mode: Mode = .korean
    private var lastLanguage: Mode = .korean
    private var shift: Shift = .off
    private var lastShiftTap = Date.distantPast
    private var symbolPage = 0
    private var punctIndex = -1
    private var punctTime = Date.distantPast

    private let container = UIView()
    private var heightConstraint: NSLayoutConstraint?
    private lazy var emojiPanel: EmojiPanelView = makeEmojiPanel()
    private var letterKeys: [(KeyView, String)] = []
    private weak var shiftKey: KeyView?
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    // MARK: 생명주기

    override func viewDidLoad() {
        super.viewDidLoad()
        container.backgroundColor = Palette.background
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        let h = view.heightAnchor.constraint(equalToConstant: keyboardHeight)
        h.priority = .required - 1
        h.isActive = true
        heightConstraint = h
        rebuild()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        engine.finish()
        applyAppearance()
        if hasFullAccess { haptic.prepare() }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        applyAppearance()
        breakCompositionIfCursorMoved()
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        breakCompositionIfCursorMoved()
    }

    /// 사용자가 커서를 옮기거나 앱이 입력창을 비우면 조합을 끊는다
    private func breakCompositionIfCursorMoved() {
        guard engine.isComposing else { return }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        if !before.hasSuffix(engine.display) { engine.finish() }
    }

    private func applyAppearance() {
        view.overrideUserInterfaceStyle = textDocumentProxy.keyboardAppearance == .dark ? .dark : .unspecified
    }

    // MARK: 화면 구성

    private func rebuild() {
        container.subviews.forEach { $0.removeFromSuperview() }
        letterKeys = []
        let content: UIView
        switch mode {
        case .korean: content = buildKorean()
        case .english: content = buildEnglish()
        case .symbols: content = buildSymbols()
        case .emoji:
            emojiPanel.reload()
            content = emojiPanel
        }
        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 3),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -3),
        ])
    }

    private func key(_ title: String? = nil, hint: String? = nil, symbol: String? = nil,
                     style: KeyStyle = .letter, size: CGFloat = 22, tap: (() -> Void)? = nil) -> KeyView {
        let k = KeyView(title: title, hint: hint, symbol: symbol, style: style, fontSize: size)
        k.onTap = tap
        k.onTouchDown = { [weak self] in self?.feedback() }
        return k
    }

    // 갤럭시 천지인 배열
    //  ㅣ   ㆍ   ㅡ   ⌫
    //  ㄱㅋ ㄴㄹ ㄷㅌ ↵
    //  ㅂㅍ ㅅㅎ ㅈㅊ .,?!
    //  !#1 한/영 ㅇㅁ ⎵ 😊
    private func buildKorean() -> UIView {
        let rows = RowsView()

        let r1 = RowView()
        r1.add(vowelKey("ㅣ", stroke: ChunjiinEngine.i, number: "1"))
        r1.add(vowelKey("ㆍ", stroke: ChunjiinEngine.dot, number: "2"))
        r1.add(vowelKey("ㅡ", stroke: ChunjiinEngine.eu, number: "3"))
        r1.add(deleteKey())

        let r2 = RowView()
        r2.add(consonantKey("ㄱㅋ", cycle: "ㄱㅋㄲ", number: "4"))
        r2.add(consonantKey("ㄴㄹ", cycle: "ㄴㄹ", number: "5"))
        r2.add(consonantKey("ㄷㅌ", cycle: "ㄷㅌㄸ", number: "6"))
        r2.add(returnKey())

        let r3 = RowView()
        r3.add(consonantKey("ㅂㅍ", cycle: "ㅂㅍㅃ", number: "7"))
        r3.add(consonantKey("ㅅㅎ", cycle: "ㅅㅎㅆ", number: "8"))
        r3.add(consonantKey("ㅈㅊ", cycle: "ㅈㅊㅉ", number: "9"))
        r3.add(punctuationKey())

        let r4 = RowView()
        r4.add(symbolsKey(), weight: 0.5)
        r4.add(languageKey(), weight: 0.5)
        r4.add(consonantKey("ㅇㅁ", cycle: "ㅇㅁ", number: "0"))
        r4.add(spaceKey())
        r4.add(emojiKey())

        [r1, r2, r3, r4].forEach { rows.addSubview($0) }
        return rows
    }

    private func vowelKey(_ title: String, stroke: Character, number: String) -> KeyView {
        let k = key(title, hint: number, size: 26) { [weak self] in
            guard let self else { return }
            self.resetPunct()
            self.apply(self.engine.inputVowel(stroke))
        }
        k.onLongPress = { [weak self] in self?.insertPlain(number) }
        return k
    }

    private func consonantKey(_ title: String, cycle: String, number: String) -> KeyView {
        let chars = Array(cycle)
        let k = key(title, hint: number, size: 22) { [weak self] in
            guard let self else { return }
            self.resetPunct()
            self.apply(self.engine.inputConsonant(key: title, cycle: chars))
        }
        k.onLongPress = { [weak self] in self?.insertPlain(number) }
        return k
    }

    private func deleteKey() -> KeyView {
        let k = key(symbol: "delete.left", style: .function)
        k.onRepeat = { [weak self] in self?.handleDelete() }
        return k
    }

    private func returnKey() -> KeyView {
        key(symbol: "return", style: .function) { [weak self] in
            self?.insertPlain("\n")
        }
    }

    private func punctuationKey() -> KeyView {
        key(".,?!", style: .function, size: 20) { [weak self] in self?.handlePunct() }
    }

    private func symbolsKey() -> KeyView {
        key("!#1", style: .function, size: 15) { [weak self] in
            guard let self else { return }
            self.engine.finish()
            self.symbolPage = 0
            self.switchMode(.symbols)
        }
    }

    private func languageKey() -> KeyView {
        key("한/영", style: .function, size: 14) { [weak self] in
            guard let self else { return }
            self.engine.finish()
            self.switchMode(self.mode == .korean ? .english : .korean)
        }
    }

    private func emojiKey() -> KeyView {
        key(symbol: "face.smiling", style: .function) { [weak self] in
            self?.engine.finish()
            self?.switchMode(.emoji)
        }
    }

    /// 스페이스: 탭하면 띄어쓰기, 좌우로 밀면 커서 이동 (갤럭시 순정처럼)
    private func spaceKey() -> KeyView {
        let k = key(symbol: "space", style: .letter) { [weak self] in self?.handleSpace() }
        k.onDragBegan = { [weak self] in
            self?.engine.finish()
            self?.resetPunct()
        }
        k.onDragStep = { [weak self] steps in
            self?.textDocumentProxy.adjustTextPosition(byCharacterOffset: steps)
        }
        return k
    }

    // 영문 쿼티
    private func buildEnglish() -> UIView {
        let rows = RowsView()
        let lines = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]

        let r1 = RowView()
        for ch in lines[0] { r1.add(letterKey(String(ch))) }

        let r2 = RowView()
        r2.add(UIView(), weight: 0.5)
        for ch in lines[1] { r2.add(letterKey(String(ch))) }
        r2.add(UIView(), weight: 0.5)

        let r3 = RowView()
        let sk = key(symbol: shift == .locked ? "capslock.fill" : (shift == .once ? "shift.fill" : "shift"),
                     style: shift == .off ? .function : .accent) { [weak self] in self?.handleShift() }
        shiftKey = sk
        r3.add(sk, weight: 1.5)
        for ch in lines[2] { r3.add(letterKey(String(ch))) }
        r3.add(deleteKey(), weight: 1.5)

        let r4 = RowView()
        r4.add(symbolsKey(), weight: 1.25)
        r4.add(languageKey(), weight: 1.25)
        r4.add(spaceKey(), weight: 4.5)
        r4.add(key(".", style: .function) { [weak self] in self?.insertPlain(".") }, weight: 1.25)
        r4.add(emojiKey(), weight: 1.25)
        r4.add(returnKey(), weight: 1.5)

        [r1, r2, r3, r4].forEach { rows.addSubview($0) }
        refreshLetterCase()
        return rows
    }

    private func letterKey(_ ch: String) -> KeyView {
        let k = key(ch, size: 23) { [weak self] in self?.handleLetter(ch) }
        letterKeys.append((k, ch))
        return k
    }

    // 숫자·기호
    private static let symbolPages: [[String]] = [
        ["1234567890", "!@#$%^&*()", "-'\":;,?/"],
        ["+×÷=_<>[]{}", "€£¥₩°•○●※♥", "~`|\\…·★☆"],
    ]

    private func buildSymbols() -> UIView {
        let rows = RowsView()
        let page = Self.symbolPages[symbolPage]

        let r1 = RowView()
        for ch in page[0] { r1.add(charKey(String(ch))) }
        let r2 = RowView()
        for ch in page[1] { r2.add(charKey(String(ch))) }

        let r3 = RowView()
        r3.add(key("\(symbolPage + 1)/2", style: .function, size: 15) { [weak self] in
            guard let self else { return }
            self.symbolPage = 1 - self.symbolPage
            self.rebuild()
        }, weight: 1.5)
        for ch in page[2] { r3.add(charKey(String(ch))) }
        r3.add(deleteKey(), weight: 1.5)

        let r4 = RowView()
        r4.add(key(lastLanguage == .korean ? "가" : "abc", style: .function, size: 17) { [weak self] in
            guard let self else { return }
            self.switchMode(self.lastLanguage)
        }, weight: 1.5)
        r4.add(key(",", style: .function) { [weak self] in self?.insertPlain(",") }, weight: 1.1)
        r4.add(spaceKey(), weight: 4.5)
        r4.add(key(".", style: .function) { [weak self] in self?.insertPlain(".") }, weight: 1.1)
        r4.add(returnKey(), weight: 1.5)

        [r1, r2, r3, r4].forEach { rows.addSubview($0) }
        return rows
    }

    private func charKey(_ ch: String) -> KeyView {
        key(ch, size: 21) { [weak self] in self?.insertPlain(ch) }
    }

    private func makeEmojiPanel() -> EmojiPanelView {
        let p = EmojiPanelView()
        p.onEmoji = { [weak self] e in self?.insertPlain(e) }
        p.onBack = { [weak self] in
            guard let self else { return }
            self.switchMode(self.lastLanguage)
        }
        p.onSpace = { [weak self] in self?.insertPlain(" ") }
        p.onDelete = { [weak self] in self?.handleDelete() }
        p.onTouchDown = { [weak self] in self?.feedback() }
        return p
    }

    private func switchMode(_ m: Mode) {
        if m == .korean || m == .english { lastLanguage = m }
        mode = m
        resetPunct()
        rebuild()
    }

    // MARK: 입력 처리

    private func apply(_ edit: TextEdit) {
        for _ in 0..<edit.deleteCount { textDocumentProxy.deleteBackward() }
        if !edit.insert.isEmpty { textDocumentProxy.insertText(edit.insert) }
    }

    /// 조합을 끝내고 그대로 넣기 (숫자, 기호, 이모지, 줄바꿈)
    private func insertPlain(_ s: String) {
        engine.finish()
        resetPunct()
        textDocumentProxy.insertText(s)
    }

    private func handleSpace() {
        resetPunct()
        if engine.spaceShouldOnlyBreak() { return }   // 같은 자음 연속 입력용 끊기
        textDocumentProxy.insertText(" ")
    }

    private func handleDelete() {
        resetPunct()
        if let edit = engine.backspace() {
            apply(edit)
        } else {
            textDocumentProxy.deleteBackward()
        }
    }

    /// .,?! 키: 연타하면 . → , → ? → ! 순환
    private func handlePunct() {
        engine.finish()
        let cycle = [".", ",", "?", "!"]
        let now = Date()
        if punctIndex >= 0, now.timeIntervalSince(punctTime) <= engine.multitapTimeout {
            textDocumentProxy.deleteBackward()
            punctIndex = (punctIndex + 1) % cycle.count
        } else {
            punctIndex = 0
        }
        textDocumentProxy.insertText(cycle[punctIndex])
        punctTime = now
    }

    private func resetPunct() { punctIndex = -1 }

    private func handleLetter(_ ch: String) {
        resetPunct()
        textDocumentProxy.insertText(shift == .off ? ch : ch.uppercased())
        if shift == .once {
            shift = .off
            refreshLetterCase()
        }
    }

    private func handleShift() {
        let now = Date()
        switch shift {
        case .off: shift = .once
        case .once: shift = now.timeIntervalSince(lastShiftTap) < 0.35 ? .locked : .off
        case .locked: shift = .off
        }
        lastShiftTap = now
        refreshLetterCase()
    }

    private func refreshLetterCase() {
        for (k, ch) in letterKeys { k.setTitle(shift == .off ? ch : ch.uppercased()) }
        shiftKey?.style = shift == .off ? .function : .accent
        shiftKey?.setSymbol(shift == .locked ? "capslock.fill" : (shift == .once ? "shift.fill" : "shift"))
    }

    // MARK: 소리·진동 (전체 접근 허용을 켰을 때만 동작)

    private func feedback() {
        guard hasFullAccess else { return }
        if enableHaptic { haptic.impactOccurred() }
        if enableSound { AudioServicesPlaySystemSound(1104) }
    }
}
