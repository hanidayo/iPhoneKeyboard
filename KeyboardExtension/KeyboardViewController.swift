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

    private enum Mode { case korean, symbols, emoji, settings }

    // MARK: 크기
    // 높이는 정하지 않고 iOS 기본 키보드 높이를 그대로 씀 → 키보드가 뜰 때 출렁임 없음

    /// 맨 아래 키의 아래 여백을 없애 키 아래 끝 = 키보드 영역 아래 끝
    private let bottomBleed: CGFloat = KeyView.verticalInset

    // MARK: 상태

    private let engine = ChunjiinEngine()
    private var mode: Mode = .korean
    private var lastLanguage: Mode = .korean
    private var symbolPage = 0
    private var punctIndex = -1
    private var punctTime = Date.distantPast

    private let content = UIView()
    private weak var spaceKeyView: KeyView?
    /// 한글 자판일 때 iOS가 준 키보드 높이. 이모티콘·설정 화면도 같은 높이로 맞춤
    private var koreanHeight: CGFloat = 216
    private var otpField = false
    private lazy var emojiPanel: EmojiPanelView = makeEmojiPanel()
    private lazy var settingsPanel: SettingsPanelView = makeSettingsPanel()
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    /// 키를 누를 때마다 증가. 빠르게 칠 때 커서 확인을 미루는 데 씀
    private var keySerial = 0

    // MARK: 생명주기

    override func viewDidLoad() {
        super.viewDidLoad()
        // 배경은 투명: iOS 키보드 배경(유리 효과)이 그대로 보여서 위쪽 둥근 부분과 색이 맞음
        view.backgroundColor = .clear

        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: view.topAnchor),
            content.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        applySettings()
        rebuild()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        engine.finish()
        applyAppearance()
        applySettings()
        if hasFullAccess { haptic.prepare() }
        updateOTPHint()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        applyAppearance()
        updateOTPHint()
        scheduleCursorCheck()
    }

    /// 앱이 '인증번호' 칸으로 지정한 입력창이면 툴바에 기본 키보드 전환 버튼 표시
    /// 인증번호 칸이면 스페이스바에 안내를 띄우고, 스페이스를 누르면 iOS 기본 키보드로 전환
    private func updateOTPHint() {
        otpField = textDocumentProxy.textContentType == .oneTimeCode
        refreshSpaceLabel()
    }

    private func refreshSpaceLabel() {
        guard let k = spaceKeyView else { return }
        if otpField {
            k.setSymbol(nil)
            k.setTitleFont(.systemFont(ofSize: 12, weight: .medium))
            k.setTitle("🌐 인증번호 자동입력")
        } else {
            k.setTitle(nil)
            k.setSymbol("space")
        }
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        scheduleCursorCheck()
    }

    /// 빠르게 칠 때는 앱이 알려주는 문서 내용이 한 박자 늦게 와서, 바로 확인하면
    /// 조합이 잘못 끊겨 오타가 났다. 키 입력이 0.4초 멈췄을 때만 확인한다.
    private func scheduleCursorCheck() {
        let serial = keySerial
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, self.keySerial == serial, self.cursorLooksMoved() else { return }
            // 앱이 내용을 늦게 알려주는 경우가 있어 한 번 더 확인한 뒤에만 조합을 끊음
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let self, self.keySerial == serial, self.cursorLooksMoved() else { return }
                self.engine.finish()
            }
        }
    }

    private func cursorLooksMoved() -> Bool {
        guard engine.isComposing else { return false }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        return !before.hasSuffix(engine.display)
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

    private func applySettings() {
        engine.multitapTimeout = KeyboardSettings.multitapTimeout
        KeyView.dragStep = KeyboardSettings.swipeStep
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if mode == .korean, view.bounds.height > 150 { koreanHeight = view.bounds.height }
    }

    // MARK: 화면 구성

    private func rebuild() {
        content.subviews.forEach { $0.removeFromSuperview() }
        let v: UIView
        switch mode {
        case .korean: v = buildKorean()
        case .symbols: v = buildSymbols()
        case .emoji:
            emojiPanel.reload()
            v = emojiPanel
        case .settings:
            settingsPanel.update(hasFullAccess: hasFullAccess)
            v = settingsPanel
        }
        v.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(v)
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo: content.topAnchor, constant: 3),
            v.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: bottomBleed),
            v.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 3),
            v.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -3),
        ])
        if mode == .emoji || mode == .settings {
            // 패널은 한글 자판과 같은 높이로 (키보드 높이가 바뀌어 출렁이지 않게)
            let h = v.heightAnchor.constraint(equalToConstant: koreanHeight - 3)
            h.priority = .defaultHigh
            h.isActive = true
        }
    }

    /// 툴바 버튼: 같은 버튼을 다시 누르면 자판으로 돌아감
    private func toggle(_ m: Mode) {
        feedback()
        engine.finish()
        switchMode(mode == m ? lastLanguage : m)
    }

    private func key(_ title: String? = nil, hint: String? = nil, symbol: String? = nil, symbolSize: CGFloat = 17,
                     style: KeyStyle = .letter, size: CGFloat = 22, tap: (() -> Void)? = nil) -> KeyView {
        let k = KeyView(title: title, hint: hint, symbol: nil, style: style, fontSize: size)
        k.symbolSize = symbolSize
        k.setSymbol(symbol)
        k.onTap = tap
        k.onTouchDown = { [weak self] in self?.feedback() }
        return k
    }

    // 갤럭시 천지인 배열
    //  ㅣ   ㆍ   ㅡ   ⌫
    //  ㄱㅋ ㄴㄹ ㄷㅌ →
    //  ㅂㅍ ㅅㅎ ㅈㅊ .,?!
    //  !#1 😊 ㅇㅁ ⎵ ↵   (영문은 iOS 기본 키보드 사용)
    private func buildKorean() -> UIView {
        let rows = RowsView()

        let r1 = RowView()
        r1.add(vowelKey("ㅣ", stroke: ChunjiinEngine.i, number: "1"))
        r1.add(vowelKey("ㆍ", stroke: ChunjiinEngine.dot, number: "2"))
        r1.add(vowelKey("ㅡ", stroke: ChunjiinEngine.eu, number: "3"))
        r1.add(deleteKey())
        roundOuterCorners(of: r1)

        let r2 = RowView()
        r2.add(consonantKey("ㄱㅋ", cycle: "ㄱㅋㄲ", number: "4"))
        r2.add(consonantKey("ㄴㄹ", cycle: "ㄴㄹ", number: "5"))
        r2.add(consonantKey("ㄷㅌ", cycle: "ㄷㅌㄸ", number: "6"))
        r2.add(arrowKey())

        let r3 = RowView()
        r3.add(consonantKey("ㅂㅍ", cycle: "ㅂㅍㅃ", number: "7"))
        r3.add(consonantKey("ㅅㅎ", cycle: "ㅅㅎㅆ", number: "8"))
        r3.add(consonantKey("ㅈㅊ", cycle: "ㅈㅊㅉ", number: "9"))
        r3.add(punctuationKey())

        let r4 = RowView()
        r4.add(symbolsKey(), weight: 0.5)
        r4.add(emojiKey(symbolSize: 17), weight: 0.5)
        r4.add(consonantKey("ㅇㅁ", cycle: "ㅇㅁ", number: "0"))
        r4.add(spaceKey())
        r4.add(returnKey())

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
        let k = key(symbol: "delete.left", symbolSize: 18, style: .function)
        k.onRepeat = { [weak self] in self?.handleDelete() }
        return k
    }

    private func returnKey() -> KeyView {
        key(symbol: "return.left", symbolSize: 17, style: .function) { [weak self] in
            self?.insertPlain("\n")
        }
    }

    /// → 키: 조합 중이면 글자를 끝내고(같은 자음 연속 입력용), 아니면 커서를 한 칸 오른쪽으로
    private func arrowKey() -> KeyView {
        key(symbol: "arrow.right", symbolSize: 16, style: .function) { [weak self] in
            guard let self else { return }
            self.resetPunct()
            if self.engine.isComposing {
                self.engine.finish()
            } else {
                self.textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
            }
        }
    }

    private func punctuationKey() -> KeyView {
        key(".,?!", style: .function, size: 17) { [weak self] in self?.handlePunct() }
    }

    private func symbolsKey() -> KeyView {
        key("!#1", style: .function, size: 15) { [weak self] in
            guard let self else { return }
            self.engine.finish()
            self.symbolPage = 0
            self.switchMode(.symbols)
        }
    }

    /// 😊: 탭 = 이모티콘, 길게 = 키보드 설정
    private func emojiKey(symbolSize: CGFloat = 19) -> KeyView {
        let k = key(symbol: "face.smiling", symbolSize: symbolSize, style: .function) { [weak self] in
            self?.engine.finish()
            self?.switchMode(.emoji)
        }
        k.onLongPress = { [weak self] in
            self?.engine.finish()
            self?.switchMode(.settings)
        }
        return k
    }

    /// 스페이스: 탭하면 띄어쓰기, 좌우로 밀면 커서 이동 (갤럭시 순정처럼)
    private func spaceKey() -> KeyView {
        let k = key(symbol: "space", symbolSize: 15, style: .letter) { [weak self] in self?.handleSpace() }
        k.onDragBegan = { [weak self] in
            self?.engine.finish()
            self?.resetPunct()
        }
        k.onDragStep = { [weak self] steps in
            self?.textDocumentProxy.adjustTextPosition(byCharacterOffset: steps)
        }
        spaceKeyView = k
        DispatchQueue.main.async { [weak self] in self?.refreshSpaceLabel() }
        return k
    }

    /// 맨 윗줄 양 끝 키의 바깥 위 모서리를 키보드 둥근 모서리에 맞춰 깎음
    private func roundOuterCorners(of row: RowView) {
        (row.subviews.first as? KeyView)?.outerCorners = .topLeft
        (row.subviews.last as? KeyView)?.outerCorners = .topRight
    }

    // 숫자·기호
    // 숫자·기호 (iOS 순정 배열)
    private static let symbolPages: [[[String]]] = [
        [["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
         ["-", "/", ":", ";", "(", ")", "₩", "&", "@", "\""]],
        [["[", "]", "{", "}", "#", "%", "^", "*", "+", "="],
         ["_", "\\", "|", "~", "<", ">", "$", "£", "¥", "•"]],
    ]

    private func buildSymbols() -> UIView {
        let rows = RowsView()
        let page = Self.symbolPages[symbolPage]

        let r1 = RowView()
        for ch in page[0] { r1.add(charKey(ch)) }
        roundOuterCorners(of: r1)
        let r2 = RowView()
        for ch in page[1] { r2.add(charKey(ch)) }

        let r3 = RowView()
        r3.add(key(symbolPage == 0 ? "#+=" : "123", style: .function, size: 15) { [weak self] in
            guard let self else { return }
            self.symbolPage = 1 - self.symbolPage
            self.rebuild()
        }, weight: 1.3)
        for ch in [".", ",", "?", "!", "'"] { r3.add(charKey(ch), weight: 1.45) }
        r3.add(deleteKey(), weight: 1.3)

        let r4 = RowView()
        r4.add(key("한글", style: .function, size: 16) { [weak self] in
            self?.switchMode(.korean)
        }, weight: 2.4)
        r4.add(spaceKey(), weight: 4.8)
        r4.add(returnKey(), weight: 2.4)

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

    private func makeSettingsPanel() -> SettingsPanelView {
        let p = SettingsPanelView()
        p.onChange = { [weak self] in self?.applySettings() }
        p.onBack = { [weak self] in
            guard let self else { return }
            self.switchMode(self.lastLanguage)
        }
        return p
    }

    private func switchMode(_ m: Mode) {
        if m == .korean { lastLanguage = m }
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
        if otpField {
            advanceToNextInputMode()
            return
        }
        resetPunct()
        engine.finish()   // 스페이스는 항상 띄어쓰기 (글자 끊기는 → 키)
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

    // MARK: 소리·진동 (전체 접근 허용을 켰을 때만 동작)

    private func feedback() {
        keySerial += 1
        guard hasFullAccess else { return }
        if KeyboardSettings.haptic { haptic.impactOccurred() }
        if KeyboardSettings.sound { AudioServicesPlaySystemSound(1104) }
    }
}
