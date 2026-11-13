import UIKit

/// 키보드 위 툴바
/// [설정][클립보드 기록]   ( 가운데: 복사한 내용 칩 / 인증번호 안내 )   [키보드 내리기]
final class ToolbarView: UIView {

    var onSettings: (() -> Void)?
    var onClipboard: (() -> Void)?
    var onPasteLatest: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onOTP: (() -> Void)?

    private let settingsButton = ToolbarView.iconButton("gearshape")
    private let clipButton = ToolbarView.iconButton("list.clipboard")
    private let dismissButton = ToolbarView.iconButton("keyboard.chevron.compact.down")
    private let chip = UIButton(type: .system)
    private let otpButton = UIButton(type: .system)
    private let hintLabel = UILabel()

    private var content: ClipContent = .none
    private var otpMode = false
    private var hintTimer: Timer?

    var currentClip: ClipContent { content }

    override init(frame: CGRect) {
        super.init(frame: frame)

        var cfg = UIButton.Configuration.filled()
        cfg.baseBackgroundColor = Palette.letter
        cfg.baseForegroundColor = Palette.text
        cfg.cornerStyle = .capsule
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 3, leading: 12, bottom: 3, trailing: 14)
        cfg.titleLineBreakMode = .byTruncatingTail
        cfg.imagePadding = 6
        chip.configuration = cfg

        var ocfg = UIButton.Configuration.filled()
        ocfg.baseBackgroundColor = Palette.accent
        ocfg.baseForegroundColor = .white
        ocfg.cornerStyle = .capsule
        ocfg.contentInsets = NSDirectionalEdgeInsets(top: 3, leading: 12, bottom: 3, trailing: 14)
        ocfg.image = UIImage(systemName: "globe", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12))
        ocfg.imagePadding = 6
        var oattr = AttributedString("인증번호 칸 · 탭하면 기본 키보드로")
        oattr.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        ocfg.attributedTitle = oattr
        ocfg.titleLineBreakMode = .byTruncatingTail
        otpButton.configuration = ocfg

        hintLabel.font = .systemFont(ofSize: 13)
        hintLabel.textColor = Palette.hint
        hintLabel.textAlignment = .center

        settingsButton.addTarget(self, action: #selector(tapSettings), for: .touchUpInside)
        clipButton.addTarget(self, action: #selector(tapClip), for: .touchUpInside)
        dismissButton.addTarget(self, action: #selector(tapDismiss), for: .touchUpInside)
        chip.addTarget(self, action: #selector(tapChip), for: .touchUpInside)
        otpButton.addTarget(self, action: #selector(tapOTP), for: .touchUpInside)

        let left = UIStackView(arrangedSubviews: [settingsButton, clipButton])
        left.axis = .horizontal
        left.spacing = 2

        for v in [left, dismissButton, chip, otpButton, hintLabel] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        var cs: [NSLayoutConstraint] = [
            left.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            left.centerYAnchor.constraint(equalTo: centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 40),
            clipButton.widthAnchor.constraint(equalToConstant: 40),
            dismissButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            dismissButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            dismissButton.widthAnchor.constraint(equalToConstant: 40),
        ]
        // 가운데 요소들: 툴바 정중앙, 양옆 버튼과 겹치지 않게 (겹칠 때만 가운데 맞춤을 양보)
        for v in [chip, otpButton, hintLabel] as [UIView] {
            let cx = v.centerXAnchor.constraint(equalTo: centerXAnchor)
            cx.priority = .defaultHigh
            cs += [
                cx,
                v.centerYAnchor.constraint(equalTo: centerYAnchor),
                v.leadingAnchor.constraint(greaterThanOrEqualTo: left.trailingAnchor, constant: 6),
                v.trailingAnchor.constraint(lessThanOrEqualTo: dismissButton.leadingAnchor, constant: -6),
            ]
        }
        cs += [chip.heightAnchor.constraint(equalToConstant: 28), otpButton.heightAnchor.constraint(equalToConstant: 28)]
        NSLayoutConstraint.activate(cs)

        chip.isHidden = true
        otpButton.isHidden = true
        hintLabel.isHidden = true
    }

    required init?(coder: NSCoder) { fatalError() }

    /// 복사한 내용 칩 (복사 후 일정 시간만 보임)
    func update(clip: ClipContent) {
        content = clip
        let title: String
        let symbol: String
        switch clip {
        case .none:
            refreshVisibility()
            return
        case .text:
            title = "복사한 글 붙여넣기"
            symbol = "doc.on.clipboard"
        case .image:
            title = "복사한 사진"
            symbol = "photo"
        }
        var attr = AttributedString(title)
        attr.font = UIFont.systemFont(ofSize: 14)
        chip.configuration?.attributedTitle = attr
        chip.configuration?.image = UIImage(systemName: symbol,
                                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12))
        refreshVisibility()
    }

    /// 인증번호 입력칸이면 안내 버튼을 칩 대신 보여줌
    func setOTPMode(_ on: Bool) {
        otpMode = on
        refreshVisibility()
    }

    /// 가운데에 잠깐 안내 문구 표시
    func showHint(_ text: String) {
        hintTimer?.invalidate()
        hintLabel.text = text
        hintLabel.isHidden = false
        refreshVisibility()
        hintTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            self?.hintLabel.isHidden = true
            self?.refreshVisibility()
        }
    }

    private func refreshVisibility() {
        let hinting = !hintLabel.isHidden
        otpButton.isHidden = !otpMode || hinting
        chip.isHidden = otpMode || hinting || content == .none
    }

    private static func iconButton(_ name: String) -> UIButton {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)),
                   for: .normal)
        b.tintColor = Palette.hint
        return b
    }

    @objc private func tapSettings() { onSettings?() }
    @objc private func tapClip() { onClipboard?() }
    @objc private func tapChip() { onPasteLatest?() }
    @objc private func tapDismiss() { onDismiss?() }
    @objc private func tapOTP() { onOTP?() }
}
