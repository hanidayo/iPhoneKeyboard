import UIKit

/// 패널 위쪽 공통 바: [가] 제목 [오른쪽 버튼]
private func panelHeader(title: String, back: UIButton, right: UIButton?) -> UIView {
    let label = UILabel()
    label.text = title
    label.font = .boldSystemFont(ofSize: 15)
    label.textColor = Palette.text
    label.textAlignment = .center
    let spacer = UIView()
    let views: [UIView] = [back, label, right ?? spacer]
    let stack = UIStackView(arrangedSubviews: views)
    stack.axis = .horizontal
    stack.distribution = .fillEqually
    stack.alignment = .center
    return stack
}

private func textButton(_ title: String, bold: Bool = false) -> UIButton {
    let b = UIButton(type: .system)
    b.setTitle(title, for: .normal)
    b.titleLabel?.font = bold ? .boldSystemFont(ofSize: 15) : .systemFont(ofSize: 15)
    b.tintColor = Palette.accent
    return b
}

// MARK: - 설정

final class SettingsPanelView: UIView {

    var onChange: (() -> Void)?
    var onBack: (() -> Void)?

    private let fullAccessNote = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let back = textButton("‹ 키보드")
        back.contentHorizontalAlignment = .leading
        back.addTarget(self, action: #selector(tapBack), for: .touchUpInside)
        let done = textButton("완료", bold: true)
        done.contentHorizontalAlignment = .trailing
        done.addTarget(self, action: #selector(tapBack), for: .touchUpInside)
        let header = panelHeader(title: "키보드 설정", back: back, right: done)

        let rows = UIStackView()
        rows.axis = .vertical
        rows.spacing = 10
        rows.isLayoutMarginsRelativeArrangement = true
        rows.layoutMargins = UIEdgeInsets(top: 6, left: 14, bottom: 12, right: 14)

        rows.addArrangedSubview(segmentRow("자음 연타 간격", ["0.5초", "0.8초", "1.0초", "1.2초"],
                                           KeyboardSettings.multitapIndex) { KeyboardSettings.multitapIndex = $0 })
        rows.addArrangedSubview(segmentRow("스페이스 커서 이동", ["느리게", "보통", "빠르게"],
                                           KeyboardSettings.swipeIndex) { KeyboardSettings.swipeIndex = $0 })
        rows.addArrangedSubview(switchRow("진동", KeyboardSettings.haptic) { KeyboardSettings.haptic = $0 })
        rows.addArrangedSubview(switchRow("키 소리", KeyboardSettings.sound) { KeyboardSettings.sound = $0 })

        fullAccessNote.font = .systemFont(ofSize: 12)
        fullAccessNote.textColor = Palette.hint
        fullAccessNote.numberOfLines = 0
        rows.addArrangedSubview(fullAccessNote)

        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        rows.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(rows)

        for v in [header, scroll] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor),
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            header.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            header.heightAnchor.constraint(equalToConstant: 34),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 150),
            rows.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            rows.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            rows.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(hasFullAccess: Bool) {
        fullAccessNote.text = hasFullAccess
            ? "전체 접근 허용: 켜짐 (진동·소리 사용 가능)"
            : "진동·키 소리는 아이폰 설정 → 일반 → 키보드 → 키보드 → 갤럭시 천지인 → '전체 접근 허용'을 켜야 동작해요."
    }

    @objc private func tapBack() { onBack?() }

    private func label(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 15)
        l.textColor = Palette.text
        return l
    }

    private func segmentRow(_ title: String, _ options: [String], _ selected: Int,
                            _ set: @escaping (Int) -> Void) -> UIView {
        let seg = UISegmentedControl(items: options)
        seg.selectedSegmentIndex = selected
        seg.addAction(UIAction { [weak self, weak seg] _ in
            guard let seg else { return }
            set(seg.selectedSegmentIndex)
            self?.onChange?()
        }, for: .valueChanged)
        let s = UIStackView(arrangedSubviews: [label(title), seg])
        s.axis = .vertical
        s.spacing = 4
        return s
    }

    private func switchRow(_ title: String, _ on: Bool, _ set: @escaping (Bool) -> Void) -> UIView {
        let sw = UISwitch()
        sw.isOn = on
        sw.addAction(UIAction { [weak self, weak sw] _ in
            guard let sw else { return }
            set(sw.isOn)
            self?.onChange?()
        }, for: .valueChanged)
        let s = UIStackView(arrangedSubviews: [label(title), sw])
        s.axis = .horizontal
        s.alignment = .center
        return s
    }
}
