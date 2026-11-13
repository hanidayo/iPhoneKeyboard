import UIKit

/// 키보드 위 툴바: [설정] [클립보드 기록] [최근 복사한 글 — 탭하면 붙여넣기] [키보드 내리기]
final class ToolbarView: UIView {

    var onSettings: (() -> Void)?
    var onClipboard: (() -> Void)?
    var onPasteLatest: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let settingsButton = ToolbarView.iconButton("gearshape")
    private let clipButton = ToolbarView.iconButton("list.clipboard")
    private let dismissButton = ToolbarView.iconButton("keyboard.chevron.compact.down")
    private let chip = UIButton(type: .system)

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

        let stack = UIStackView(arrangedSubviews: [settingsButton, clipButton, chip, dismissButton])
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

    /// 최근 복사한 글 표시 갱신
    func update(latest: String?, hasFullAccess: Bool) {
        let title: String
        if !hasFullAccess {
            title = "클립보드: 설정에서 '전체 접근 허용' 필요"
            chip.isEnabled = false
        } else if let latest {
            let oneLine = latest.replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespaces)
            title = String(oneLine.prefix(60))
            chip.isEnabled = true
        } else {
            title = "복사한 글이 여기 표시돼요"
            chip.isEnabled = false
        }
        var attr = AttributedString(title)
        attr.font = UIFont.systemFont(ofSize: 14)
        chip.configuration?.attributedTitle = attr
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
}
