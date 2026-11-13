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
