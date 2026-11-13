import UIKit

/// 한자 키 대신 들어간 이모티콘 패널.
final class EmojiPanelView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    var onEmoji: ((String) -> Void)?
    var onBack: (() -> Void)?
    var onSpace: (() -> Void)?
    var onDelete: (() -> Void)?
    var onTouchDown: (() -> Void)?

    private static let recentKey = "recentEmojis"
    private static let recentMax = 40

    private var tabs: [(icon: String, emojis: () -> [String])] = []
    private var selected = 0
    private var items: [String] = []

    private let tabStack = UIStackView()
    private var tabButtons: [UIButton] = []
    private let collection: UICollectionView
    private let bottomStack = UIStackView()

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)

        tabs.append((icon: "🕘", emojis: { Self.recents() }))
        for c in EmojiData.categories {
            tabs.append((icon: c.icon, emojis: { c.emojis }))
        }

        tabStack.axis = .horizontal
        tabStack.distribution = .fillEqually
        for (idx, tab) in tabs.enumerated() {
            let b = UIButton(type: .system)
            b.setTitle(tab.icon, for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 18)
            b.layer.cornerRadius = 6
            b.tag = idx
            b.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            tabButtons.append(b)
            tabStack.addArrangedSubview(b)
        }

        collection.backgroundColor = .clear
        collection.dataSource = self
        collection.delegate = self
        collection.register(EmojiCell.self, forCellWithReuseIdentifier: "c")
        collection.showsVerticalScrollIndicator = false

        bottomStack.axis = .horizontal
        bottomStack.spacing = 0
        let back = KeyView(title: "가", style: .function, fontSize: 17)
        back.onTap = { [weak self] in self?.onBack?() }
        let space = KeyView(symbol: "space", style: .letter)
        space.onTap = { [weak self] in self?.onSpace?() }
        let del = KeyView(symbol: "delete.left", style: .function)
        del.onRepeat = { [weak self] in self?.onDelete?() }
        for k in [back, space, del] {
            k.onTouchDown = { [weak self] in self?.onTouchDown?() }
            bottomStack.addArrangedSubview(k)
        }
        back.widthAnchor.constraint(equalTo: bottomStack.widthAnchor, multiplier: 0.22).isActive = true
        del.widthAnchor.constraint(equalTo: back.widthAnchor).isActive = true

        for v in [tabStack, collection, bottomStack] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        NSLayoutConstraint.activate([
            tabStack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            tabStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            tabStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            tabStack.heightAnchor.constraint(equalToConstant: 34),

            collection.topAnchor.constraint(equalTo: tabStack.bottomAnchor, constant: 2),
            collection.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            collection.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            collection.bottomAnchor.constraint(equalTo: bottomStack.topAnchor),

            bottomStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
            bottomStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
            bottomStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomStack.heightAnchor.constraint(equalToConstant: 52),
        ])

        // 최근 항목이 없으면 첫 카테고리부터
        select(Self.recents().isEmpty ? 1 : 0)
    }

    required init?(coder: NSCoder) { fatalError() }

    func reload() {
        select(selected == 0 && Self.recents().isEmpty ? 1 : selected)
    }

    private func select(_ idx: Int) {
        selected = idx
        items = tabs[idx].emojis()
        for b in tabButtons {
            b.backgroundColor = b.tag == idx ? Palette.function : .clear
        }
        collection.reloadData()
        collection.setContentOffset(.zero, animated: false)
    }

    @objc private func tabTapped(_ b: UIButton) {
        onTouchDown?()
        select(b.tag)
    }

    // MARK: 최근 사용

    static func recents() -> [String] {
        UserDefaults.standard.stringArray(forKey: recentKey) ?? []
    }

    private static func pushRecent(_ e: String) {
        var r = recents().filter { $0 != e }
        r.insert(e, at: 0)
        UserDefaults.standard.set(Array(r.prefix(recentMax)), forKey: recentKey)
    }

    // MARK: 컬렉션뷰

    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }

    func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "c", for: ip) as! EmojiCell
        cell.label.text = items[ip.item]
        return cell
    }

    func collectionView(_ cv: UICollectionView, layout: UICollectionViewLayout,
                        sizeForItemAt ip: IndexPath) -> CGSize {
        let perRow: CGFloat = 8
        let w = floor(cv.bounds.width / perRow)
        return CGSize(width: w, height: 42)
    }

    func collectionView(_ cv: UICollectionView, didSelectItemAt ip: IndexPath) {
        let e = items[ip.item]
        onTouchDown?()
        onEmoji?(e)
        Self.pushRecent(e)
        // 최근 탭을 보고 있을 때는 순서가 바로 바뀌지 않게 둠 (누르던 위치가 흔들리지 않도록)
    }
}

final class EmojiCell: UICollectionViewCell {
    let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 30)
        label.textAlignment = .center
        contentView.addSubview(label)
        let sel = UIView()
        sel.backgroundColor = Palette.pressed
        sel.layer.cornerRadius = 8
        selectedBackgroundView = sel
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = contentView.bounds
    }
}
