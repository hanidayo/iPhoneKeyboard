import UIKit

enum KeyStyle {
    case letter      // 흰 키
    case function    // 회색 키
    case accent      // 강조 (Shift 켜짐 등)
}

enum Palette {
    static func dyn(_ light: UIColor, _ dark: UIColor) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? dark : light }
    }
    static let background = dyn(UIColor(red: 0.93, green: 0.93, blue: 0.95, alpha: 1),
                                UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1))
    static let letter = dyn(.white, UIColor(red: 0.27, green: 0.27, blue: 0.29, alpha: 1))
    static let function = dyn(UIColor(red: 0.85, green: 0.86, blue: 0.89, alpha: 1),
                              UIColor(red: 0.19, green: 0.19, blue: 0.21, alpha: 1))
    static let pressed = dyn(UIColor(red: 0.76, green: 0.78, blue: 0.82, alpha: 1),
                             UIColor(red: 0.40, green: 0.40, blue: 0.43, alpha: 1))
    static let accent = dyn(UIColor(red: 0.20, green: 0.45, blue: 0.95, alpha: 1),
                            UIColor(red: 0.30, green: 0.55, blue: 1.00, alpha: 1))
    static let text = dyn(.black, .white)
    static let hint = dyn(UIColor(white: 0.45, alpha: 1), UIColor(white: 0.65, alpha: 1))
}

/// 키 하나. 터치를 직접 처리해서 탭 / 길게 누르기 / 반복 / 가로 드래그를 지원한다.
final class KeyView: UIView {

    var onTap: (() -> Void)?
    /// 길게 누르면 실행 (설정하면 탭은 손을 뗄 때 실행됨)
    var onLongPress: (() -> Void)?
    /// 누르고 있는 동안 반복 (백스페이스)
    var onRepeat: (() -> Void)?
    /// 가로 드래그 (스페이스 커서 이동). 인자: 이동할 글자 수 (+오른쪽 / -왼쪽)
    var onDragStep: ((Int) -> Void)?
    var onDragBegan: (() -> Void)?
    /// 누르는 순간 (소리/진동)
    var onTouchDown: (() -> Void)?

    var style: KeyStyle { didSet { updateColors() } }

    private let titleLabel = UILabel()
    private let hintLabel = UILabel()
    private let iconView = UIImageView()
    private let bg = UIView()

    private var longTimer: Timer?
    private var repeatTimer: Timer?
    private var longFired = false
    private var startX: CGFloat = 0
    private var lastStepX: CGFloat = 0
    private var dragging = false

    static let dragThreshold: CGFloat = 20
    /// 키 위아래 여백 (키 사이 세로 간격 = 2배)
    static let verticalInset: CGFloat = 3.5
    /// 커서 1칸 이동 거리 (설정에서 바뀜)
    static var dragStep: CGFloat = 9

    init(title: String? = nil, hint: String? = nil, symbol: String? = nil, style: KeyStyle = .letter,
         fontSize: CGFloat = 22) {
        self.style = style
        super.init(frame: .zero)
        isMultipleTouchEnabled = true

        bg.layer.cornerRadius = 7
        bg.layer.cornerCurve = .continuous
        bg.isUserInteractionEnabled = false
        bg.layer.shadowColor = UIColor.black.cgColor
        bg.layer.shadowOpacity = 0.12
        bg.layer.shadowRadius = 0
        bg.layer.shadowOffset = CGSize(width: 0, height: 1)
        addSubview(bg)

        titleLabel.textAlignment = .center
        titleLabel.font = .systemFont(ofSize: fontSize)
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.5
        titleLabel.textColor = Palette.text
        bg.addSubview(titleLabel)

        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = Palette.hint
        hintLabel.text = hint
        bg.addSubview(hintLabel)

        iconView.contentMode = .center   // 아이콘을 키 크기에 맞춰 키우지 않음
        iconView.tintColor = Palette.text
        bg.addSubview(iconView)

        setTitle(title)
        setSymbol(symbol)
        updateColors()
    }

    required init?(coder: NSCoder) { fatalError() }

    func setTitle(_ t: String?) {
        titleLabel.text = t
        titleLabel.isHidden = (t == nil)
    }

    /// 기능키 아이콘 크기
    var symbolSize: CGFloat = 17

    func setSymbol(_ name: String?) {
        if let name {
            iconView.image = UIImage(systemName: name,
                                     withConfiguration: UIImage.SymbolConfiguration(pointSize: symbolSize, weight: .light))
            iconView.isHidden = false
        } else {
            iconView.isHidden = true
        }
    }

    func setTitleFont(_ f: UIFont) { titleLabel.font = f }

    override func layoutSubviews() {
        super.layoutSubviews()
        bg.frame = bounds.insetBy(dx: 3, dy: Self.verticalInset)
        titleLabel.frame = bg.bounds.insetBy(dx: 4, dy: 2)
        iconView.frame = bg.bounds
        hintLabel.sizeToFit()
        hintLabel.frame.origin = CGPoint(x: bg.bounds.width - hintLabel.bounds.width - 5, y: 2)
    }

    private func updateColors(pressed: Bool = false) {
        switch style {
        case .letter: bg.backgroundColor = pressed ? Palette.pressed : Palette.letter
        case .function: bg.backgroundColor = pressed ? Palette.pressed : Palette.function
        case .accent: bg.backgroundColor = Palette.accent
        }
        let onAccent = style == .accent
        titleLabel.textColor = onAccent ? .white : Palette.text
        iconView.tintColor = onAccent ? .white : Palette.text
    }

    // MARK: - 터치

    /// 길게 누르기/드래그를 추적하는 첫 번째 손가락. 그 사이 같은 키를 다른 손가락으로 또 누르면 바로 입력.
    private weak var primary: UITouch?
    /// 아직 손가락이 안 떨어져서 입력이 대기 중인 키 (키보드 전체에서 하나)
    private static weak var pendingKey: KeyView?
    private var primaryStart = Date()

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            onTouchDown?()
            if primary != nil {
                // 빠르게 칠 때 앞 손가락이 아직 안 떨어진 상태 → 앞 입력을 먼저 처리하고 새 터치를 주 터치로
                finishPrimary(fire: true)
            }
            beginPrimary(t)
        }
    }

    private func beginPrimary(_ t: UITouch) {
        // 누른 순서대로 입력: 다른 키가 아직 대기 중이면 그 키를 먼저 입력 처리
        // (두 손가락이 겹칠 때 뒤에 누른 키가 먼저 떨어져서 ㆍㅣ 순서가 뒤바뀌던 문제)
        if let other = KeyView.pendingKey, other !== self { other.flushPending() }
        KeyView.pendingKey = self
        primary = t
        primaryStart = Date()
        startX = t.location(in: self).x
        lastStepX = startX
        dragging = false
        longFired = false
        updateColors(pressed: true)

        if let onRepeat {
            onRepeat()
            repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
                self?.repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.07, repeats: true) { _ in
                    self?.onRepeat?()
                }
            }
        } else if onLongPress != nil {
            longTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
                guard let self, !self.dragging else { return }
                self.longFired = true
                self.onLongPress?()
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard onDragStep != nil, let t = primary, touches.contains(t) else { return }
        let p = t.location(in: self)
        // 빠르게 칠 때 살짝 미끄러진 건 탭으로 처리: 충분히(가로로) 움직였을 때만 커서 이동 시작
        if !dragging, abs(p.x - startX) > Self.dragThreshold,
           Date().timeIntervalSince(primaryStart) > 0.08 {
            dragging = true
            lastStepX = p.x
            longTimer?.invalidate()
            onDragBegan?()
        }
        guard dragging else { return }
        let steps = Int((p.x - lastStepX) / Self.dragStep)
        if steps != 0 {
            lastStepX += CGFloat(steps) * Self.dragStep
            onDragStep?(steps)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let p = primary, touches.contains(p) { finishPrimary(fire: true) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let p = primary, touches.contains(p) { finishPrimary(fire: false) }
    }

    /// 다른 키가 눌렸을 때 호출: 커서 이동(드래그) 중이 아니면 지금 입력 처리
    private func flushPending() {
        guard primary != nil, !dragging else { return }
        finishPrimary(fire: true)
    }

    private func finishPrimary(fire: Bool) {
        if KeyView.pendingKey === self { KeyView.pendingKey = nil }
        longTimer?.invalidate(); longTimer = nil
        repeatTimer?.invalidate(); repeatTimer = nil
        updateColors(pressed: false)
        let shouldFire = fire && onRepeat == nil && !dragging && !longFired
        primary = nil
        dragging = false
        longFired = false
        if shouldFire { onTap?() }
    }
}
