import UIKit

/// 키보드 위 툴바
/// [설정]   ( 가운데: 인증번호 칸 안내 )   [키보드 내리기]
final class ToolbarView: UIView {

    var onSettings: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onOTP: (() -> Void)?

    private let settingsButton = ToolbarView.iconButton("gearshape")
    private let dismissButton = ToolbarView.iconButton("keyboard.chevron.compact.down")
    private let otpButton = UIButton(type: .system)

    private var otpMode = false

    override init(frame: CGRect) {
        super.init(frame: frame)

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

        settingsButton.addTarget(self, action: #selector(tapSettings), for: .touchUpInside)
        dismissButton.addTarget(self, action: #selector(tapDismiss), for: .touchUpInside)
        otpButton.addTarget(self, action: #selector(tapOTP), for: .touchUpInside)

        let left = UIStackView(arrangedSubviews: [settingsButton])
        left.axis = .horizontal
        left.spacing = 2

        for v in [left, dismissButton, otpButton] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        var cs: [NSLayoutConstraint] = [
            left.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            left.centerYAnchor.constraint(equalTo: centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 40),
            dismissButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            dismissButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            dismissButton.widthAnchor.constraint(equalToConstant: 40),
        ]
        // 가운데 요소들: 툴바 정중앙, 양옆 버튼과 겹치지 않게 (겹칠 때만 가운데 맞춤을 양보)
        for v in [otpButton] as [UIView] {
            let cx = v.centerXAnchor.constraint(equalTo: centerXAnchor)
            cx.priority = .defaultHigh
            cs += [
                cx,
                v.centerYAnchor.constraint(equalTo: centerYAnchor),
                v.leadingAnchor.constraint(greaterThanOrEqualTo: left.trailingAnchor, constant: 6),
                v.trailingAnchor.constraint(lessThanOrEqualTo: dismissButton.leadingAnchor, constant: -6),
            ]
        }
        cs += [otpButton.heightAnchor.constraint(equalToConstant: 28)]
        NSLayoutConstraint.activate(cs)

        otpButton.isHidden = true
    }

    required init?(coder: NSCoder) { fatalError() }

    /// 인증번호 입력칸이면 안내 버튼을 칩 대신 보여줌
    func setOTPMode(_ on: Bool) {
        otpMode = on
        refreshVisibility()
    }

    private func refreshVisibility() {
        otpButton.isHidden = !otpMode
    }

    private static func iconButton(_ name: String) -> UIButton {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)),
                   for: .normal)
        b.tintColor = Palette.hint
        return b
    }

    @objc private func tapSettings() { onSettings?() }
    @objc private func tapDismiss() { onDismiss?() }
    @objc private func tapOTP() { onOTP?() }
}
