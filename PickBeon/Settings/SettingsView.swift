import SwiftUI

// GifJot식 사이드바 설정. 자동 저장.
struct SettingsView: View {
    @ObservedObject var s = AppSettings.shared
    @State private var sel = 0

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 9) {
                    Text("◈").font(.system(size: 14)).frame(width: 26, height: 26)
                        .background(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .foregroundColor(.white).clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("PickBeon").font(.system(size: 13, weight: .bold))
                        Text(String(localized: "설정")).font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }.padding(.horizontal, 8).padding(.bottom, 8).padding(.top, 4)
                TextField(String(localized: "⌕ 설정 검색"), text: .constant("")).textFieldStyle(.roundedBorder).font(.system(size: 12)).padding(.horizontal, 10).padding(.bottom, 8).disabled(true)
                Nav(0, "◰", String(localized: "캡쳐")); Nav(1, "🌐", String(localized: "번역")); Nav(2, "⌨", String(localized: "단축키")); Nav(3, "🕘", String(localized: "기록")); Nav(4, "🎨", String(localized: "외관"))
                Spacer()
            }.frame(width: 190).padding(.vertical, 12).padding(.horizontal, 6)
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                if sel == 0 {
                    SHead(String(localized: "캡쳐"), String(localized: "무엇을 캡쳐하고, 캡쳐 후 어떻게 끝낼지."))
                    SCard(String(localized: "캡쳐 후 번역 카드"), String(localized: "결과 카드 띄우고 번역 복사, 닫기 전까지 유지")) { Toggle("", isOn: .constant(true)).labelsHidden() }
                    SCard(String(localized: "원본 이미지도 저장"), String(localized: "PNG 썸네일을 기록에 함께 보관")) { Toggle("", isOn: $s.saveImages).labelsHidden() }
                    SCard(String(localized: "번역 박스 기본 표시"), String(localized: "에디터에서 Vision 박스 켜기")) { Toggle("", isOn: $s.overlayOn).labelsHidden() }
                } else if sel == 1 {
                    SHead(String(localized: "번역"), String(localized: "언어와 말투, 엔진."))
                    SCard(String(localized: "UI 언어"), String(localized: "기본은 시스템 언어")) {
                        Picker("", selection: $s.uiLanguage) { Text(String(localized: "시스템 기본")).tag("system"); Text("한국어").tag("ko"); Text("English").tag("en") }.labelsHidden().frame(width: 130)
                    }
                    SCard(String(localized: "번역 타겟"), String(localized: "기본은 시스템 언어")) {
                        Picker("", selection: $s.tgtLang) { Text(String(localized: "시스템 언어")).tag("system"); Text("한국어").tag("ko"); Text("English").tag("en") }.labelsHidden().frame(width: 130)
                    }
                    SCard(String(localized: "정중한 말투"), String(localized: "끄면 반말에 가깝게")) { Toggle("", isOn: $s.politeTone).labelsHidden() }
                    Text(String(localized: "엔진: Apple Translation (온디바이스). BYOK는 추후 재검토.")).font(.system(size: 11.5)).foregroundColor(.secondary).padding(.top, 4)
                } else if sel == 2 {
                    SHead(String(localized: "단축키"), String(localized: "전역 단축키 (Carbon, 추가 권한 없음)."))
                    SCard(String(localized: "영역 Pick"), "⌥⌃P") { EmptyView() }
                    SCard(String(localized: "텍스트 선택 번역"), "⌥⌃Z") { EmptyView() }
                    SCard(String(localized: "오버레이: 마지막 영역"), "R") { EmptyView() }
                    SCard(String(localized: "오버레이: 확정(번역)"), "Enter") { EmptyView() }
                    SCard(String(localized: "오버레이: 취소"), "Esc") { EmptyView() }
                } else if sel == 3 {
                    SHead(String(localized: "기록"), String(localized: "클립보드 + 번역 히스토리 보관."))
                    SCard(String(localized: "저장 개수"), String(localized: "핀은 개수에서 제외")) {
                        Picker("", selection: $s.historyLimitRaw) { Text("20").tag(20); Text("50").tag(50); Text("100").tag(100); Text("200").tag(200); Text(String(localized: "무제한")).tag(-1) }.labelsHidden().frame(width: 110)
                    }
                    SCard(String(localized: "이미지 저장"), String(localized: "PNG 썸네일 보관")) { Toggle("", isOn: $s.saveImages).labelsHidden() }
                    SCard(String(localized: "암호화"), String(localized: "P1: AES-256-GCM")) { Toggle("", isOn: $s.encryptStore).labelsHidden() }
                } else {
                    SHead(String(localized: "외관"), String(localized: "카드와 오버레이 표시."))
                    SCard(String(localized: "번역 박스 기본 표시"), "") { Toggle("", isOn: $s.overlayOn).labelsHidden() }
                }
                Spacer()
                HStack {
                    Text(String(localized: "자동으로 저장됨.")).font(.system(size: 11.5)).foregroundColor(.secondary)
                    Spacer()
                    Button(String(localized: "설정 초기화")) { UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "") }.font(.system(size: 12))
                }.padding(.top, 8)
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }.frame(width: 640, height: 430)
    }

    private func Nav(_ i: Int, _ icon: String, _ t: String) -> some View {
        Button { sel = i } label: {
            HStack(spacing: 8) { Text(icon).font(.system(size: 13)); Text(t).font(.system(size: 13)) }
                .padding(.horizontal, 10).padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
                .background(sel == i ? Color.white.opacity(0.09) : Color.clear).clipShape(RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain)
    }
    private func SHead(_ t: String, _ d: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(t).font(.system(size: 16, weight: .bold)); Text(d).font(.system(size: 12)).foregroundColor(.secondary)
        }.padding(.bottom, 14)
    }
    private func SCard<V: View>(_ t: String, _ d: String, @ViewBuilder _ c: () -> V) -> some View {
        HStack { VStack(alignment: .leading, spacing: 2) { Text(t).font(.system(size: 13, weight: .semibold)); if !d.isEmpty { Text(d).font(.system(size: 12)).foregroundColor(.secondary) } }; Spacer(); c() }
            .padding(13).background(Color.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.bottom, 10)
    }
}
