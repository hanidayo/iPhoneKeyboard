import SwiftUI

@main
struct GalaxyKeyboardApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("키보드 켜기") {
                    Text("1. 설정 → 일반 → 키보드 → 키보드 → 새로운 키보드 추가")
                    Text("2. '갤럭시 천지인' 선택")
                    Text("3. 진동을 쓰려면 추가한 키보드를 눌러 '전체 접근 허용' 켜기 (선택)")
                    Button("설정 열기") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                Section("사용법") {
                    Text("• 같은 자음을 연속으로 쓸 때: → 키 (예: 안 → → → 녕)")
                    Text("• 스페이스를 좌우로 밀면 커서 이동")
                    Text("• 천지인 키를 길게 누르면 숫자")
                    Text("• .,?! 키를 연타하면 . , ? ! 순환")
                }
                Section("테스트") {
                    TextField("여기에 입력해 보세요", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle("갤럭시 천지인")
        }
    }
}
