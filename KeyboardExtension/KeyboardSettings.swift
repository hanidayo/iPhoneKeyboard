import UIKit

/// 키보드 안 설정 화면에서 바꾸는 값들 (키보드 확장 자체 저장소에 저장)
enum KeyboardSettings {
    private static let d = UserDefaults.standard

    static let multitapOptions: [Double] = [0.5, 0.8, 1.0, 1.2]
    static let swipeOptions: [CGFloat] = [14, 9, 6]          // 느리게 / 보통 / 빠르게
    static let rowHeightOptions: [CGFloat] = [52, 56, 60]    // 낮게 / 보통 / 높게

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

/// 지금 시스템 클립보드에 들어 있는 것의 종류 (내용은 읽지 않음 → '붙여넣기 허용' 창이 안 뜸)
enum ClipContent {
    case none
    case text
    case image
}

/// 복사한 글 기록 + 툴바 칩 상태.
/// 내용(pb.string)을 읽으면 iOS가 '붙여넣기 허용' 창을 띄우므로, 칩을 누를 때만 읽는다.
enum ClipboardStore {
    private static let d = UserDefaults.standard
    private static let itemsKey = "clipItems"
    private static let countKey = "clipChangeCount"
    private static let seenAtKey = "clipSeenAt"
    static let maxItems = 30
    /// 복사 후 툴바 칩이 보이는 시간(초)
    static let chipLifetime: TimeInterval = 60

    static var items: [String] {
        get { d.stringArray(forKey: itemsKey) ?? [] }
        set { d.set(Array(newValue.prefix(maxItems)), forKey: itemsKey) }
    }

    /// 칩에 보여줄 상태. 새로 복사된 게 있으면 그 시점부터 chipLifetime 동안만 보임.
    static func chipState(hasFullAccess: Bool) -> ClipContent {
        guard hasFullAccess else { return .none }
        let pb = UIPasteboard.general
        let count = pb.changeCount
        let now = Date().timeIntervalSince1970
        if count != d.integer(forKey: countKey) {
            d.set(count, forKey: countKey)
            d.set(now, forKey: seenAtKey)
        }
        guard now - d.double(forKey: seenAtKey) < chipLifetime else { return .none }
        if pb.hasStrings { return .text }      // has* 는 허용 창을 띄우지 않음
        if pb.hasImages { return .image }
        return .none
    }

    /// 남은 표시 시간(초)
    static var chipRemaining: TimeInterval {
        max(0, chipLifetime - (Date().timeIntervalSince1970 - d.double(forKey: seenAtKey)))
    }

    /// 칩을 눌렀을 때만 실제로 읽음 (여기서 허용 창이 뜰 수 있음)
    static func readTextAndRemember() -> String? {
        guard let s = UIPasteboard.general.string,
              !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        add(s)
        return s
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
