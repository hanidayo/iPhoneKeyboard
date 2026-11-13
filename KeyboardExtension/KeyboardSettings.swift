import UIKit

/// 키보드 안 설정 화면에서 바꾸는 값들 (키보드 확장 자체 저장소에 저장)
enum KeyboardSettings {
    private static let d = UserDefaults.standard

    static let multitapOptions: [Double] = [0.5, 0.8, 1.0, 1.2]
    static let swipeOptions: [CGFloat] = [14, 9, 6]          // 느리게 / 보통 / 빠르게
    static let rowHeightOptions: [CGFloat] = [48, 54, 60]    // 낮게 / 보통 / 높게

    static var multitapIndex: Int {
        get { d.object(forKey: "multitapIndex") as? Int ?? 1 }
        set { d.set(newValue, forKey: "multitapIndex") }
    }
    static var swipeIndex: Int {
        get { d.object(forKey: "swipeIndex") as? Int ?? 1 }
        set { d.set(newValue, forKey: "swipeIndex") }
    }
    static var heightIndex: Int {
        get { d.object(forKey: "heightIndex") as? Int ?? 1 }
        set { d.set(newValue, forKey: "heightIndex") }
    }
    static var haptic: Bool {
        get { d.object(forKey: "haptic") as? Bool ?? true }
        set { d.set(newValue, forKey: "haptic") }
    }
    static var sound: Bool {
        get { d.object(forKey: "sound") as? Bool ?? false }
        set { d.set(newValue, forKey: "sound") }
    }

    static var multitapTimeout: Double { multitapOptions[clamp(multitapIndex, multitapOptions.count)] }
    static var swipeStep: CGFloat { swipeOptions[clamp(swipeIndex, swipeOptions.count)] }
    static var rowHeight: CGFloat { rowHeightOptions[clamp(heightIndex, rowHeightOptions.count)] }

    private static func clamp(_ i: Int, _ n: Int) -> Int { min(max(i, 0), n - 1) }
}

/// 지금 시스템 클립보드에 들어 있는 것
enum ClipContent {
    case none
    case text(String)
    case image(UIImage)
}

/// 복사한 글 기록. 시스템 클립보드는 '전체 접근 허용'일 때만 읽을 수 있다.
enum ClipboardStore {
    private static let d = UserDefaults.standard
    private static let itemsKey = "clipItems"
    private static let countKey = "clipChangeCount"
    static let maxItems = 30

    static var items: [String] {
        get { d.stringArray(forKey: itemsKey) ?? [] }
        set { d.set(Array(newValue.prefix(maxItems)), forKey: itemsKey) }
    }

    /// 클립보드가 바뀌었으면 기록에 추가. 바뀐 게 있으면 true.
    @discardableResult
    static func refresh(hasFullAccess: Bool) -> Bool {
        guard hasFullAccess else { return false }
        let pb = UIPasteboard.general
        let count = pb.changeCount
        guard count != d.integer(forKey: countKey) else { return false }
        d.set(count, forKey: countKey)
        guard pb.hasStrings, let s = pb.string,
              !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        add(s)
        return true
    }

    /// 지금 클립보드 내용 (사진이면 작은 미리보기)
    static func current(hasFullAccess: Bool) -> ClipContent {
        guard hasFullAccess else { return .none }
        let pb = UIPasteboard.general
        if pb.hasStrings, let s = pb.string,
           !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .text(s)
        }
        if pb.hasImages, let img = pb.image {
            let size = CGSize(width: 24, height: 24)
            let thumb = UIGraphicsImageRenderer(size: size).image { _ in
                UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 5).addClip()
                // 가운데를 꽉 채우도록 잘라서 그림
                let scale = max(size.width / img.size.width, size.height / img.size.height)
                let w = img.size.width * scale, h = img.size.height * scale
                img.draw(in: CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h))
            }
            return .image(thumb.withRenderingMode(.alwaysOriginal))
        }
        return .none
    }

    static func add(_ s: String) {
        var list = items.filter { $0 != s }
        list.insert(s, at: 0)
        items = list
    }

    static func remove(at i: Int) {
        var list = items
        guard list.indices.contains(i) else { return }
        list.remove(at: i)
        items = list
    }

    static func clear() { items = [] }
}
