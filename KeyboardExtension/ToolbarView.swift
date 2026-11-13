import UIKit

/// 키보드 위 툴바: [설정] [클립보드 기록] [최근 복사한 글 — 탭하면 붙여넣기] [키보드 내리기]
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
    private let spacer = UIView()
    private let hintLabel = UILabel()
    private var content: ClipContent = .none
    private var hintTimer: Timer?
    private let otpButton = UIButton(type: .system)
    private var otpMode = false

    override init(frame: CGRect) {
        super.init(frame: frame)

        var cfg = UIButton.Configuration.filled()
        cfg.baseBackgroundColor = Palette.letter
        cfg.baseForegroundColor = Palette.text
        cfg.cornerStyle = .capsule
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
        cfg.titleLineBreakMode = .byTruncatingTail
        cfg.image = UIImage(systemName: "doc.on.clipboard",
                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12))
        cfg.imagePadding = 6
        chip.configuration = cfg
        chip.contentHorizontalAlignment = .leading

        settingsButton.addTarget(self, action: #selector(tapSettings), for: .touchUpInside)
        clipButton.addTarget(self, action: #selector(tapClip), for: .touchUpInside)
        dismissButton.addTarget(self, action: #selector(tapDismiss), for: .touchUpInside)
        chip.addTarget(self, action: #selector(tapChip), for: .touchUpInside)

        // 클립보드가 비어 있으면 칩을 숨기고 빈 공간이 대신 늘어남
        spacer.setContentHuggingPriority(UILayoutPriority(251), for: .horizontal)
        chip.setContentHuggingPriority(UILayoutPriority(250), for: .horizontal)
        chip.isHidden = true

        hintLabel.font = .systemFont(ofSize: 13)
        hintLabel.textColor = Palette.hint
        hintLabel.textAlignment = .center
        hintLabel.isHidden = true

        // 인증번호 칸 안내: 누르면 다음 키보드(iOS 기본)로 전환 → 문자 인증번호 자동 입력
        var ocfg = UIButton.Configuration.filled()
        ocfg.baseBackgroundColor = Palette.accent
        ocfg.baseForegroundColor = .white
        ocfg.cornerStyle = .capsule
        ocfg.image = UIImage(systemName: "globe", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12))
        ocfg.imagePadding = 6
        var oattr = AttributedString("인증번호 칸 · 탭하면 기본 키보드로")
        oattr.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        ocfg.attributedTitle = oattr
        ocfg.titleLineBreakMode = .byTruncatingTail
        otpButton.configuration = ocfg
        otpButton.isHidden = true
        otpButton.setContentHuggingPriority(UILayoutPriority(250), for: .horizontal)
        otpButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        otpButton.addTarget(self, action: #selector(tapOTP), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [settingsButton, clipButton, otpButton, chip, hintLabel, spacer, dismissButton])
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 40),
            clipButton.widthAnchor.constraint(equalToConstant: 40),
            dismissButton.widthAnchor.constraint(equalToConstant: 40),
            chip.heightAnchor.constraint(equalToConstant: 30),
        ])
        chip.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// 클립보드 칩 갱신: 글이나 사진이 있을 때만 보임
    func update(clip: ClipContent) {
        content = clip
        var title = ""
        var image: UIImage?
        switch clip {
        case .none:
            chip.isHidden = true
            return
        case .text(let t):
            title = String(t.replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespaces).prefix(60))
            image = UIImage(systemName: "doc.on.clipboard",
                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12))
        case .image(let thumb):
            title = "사진 붙여넣기"
            image = thumb
        }
        var attr = AttributedString(title)
        attr.font = UIFont.systemFont(ofSize: 14)
        chip.configuration?.attributedTitle = attr
        chip.configuration?.image = image
        chip.isHidden = !hintLabel.isHidden || otpMode
    }

    /// 인증번호 입력칸이면 안내 버튼을 클립보드 칩 대신 보여줌
    func setOTPMode(_ on: Bool) {
        guard on != otpMode else { return }
        otpMode = on
        otpButton.isHidden = !on
        if on { chip.isHidden = true; hintLabel.isHidden = true } else { update(clip: content) }
    }

    /// 칩 자리에 잠깐 안내 문구 표시
    func showHint(_ text: String) {
        hintTimer?.invalidate()
        hintLabel.text = text
        hintLabel.isHidden = false
        chip.isHidden = true
        hintTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.hintLabel.isHidden = true
            self.update(clip: self.content)
        }
    }

    var currentClip: ClipContent { content }

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
