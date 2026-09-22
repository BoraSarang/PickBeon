import SwiftUI

// 합의 레이아웃: 좌 이미지 / 우 OCR / 하 번역 전체. 자동 높이.
struct ResultCardView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: 0) {
            switch coordinator.cardMode {
            case .translation: translationBody
            case .message: messageBody
            case .error: errorBody
            }
        }.frame(width: 460)
    }

    private var translationBody: some View {
        VStack(spacing: 0) {
            header(dot: "✓", dotColor: .green, title: String(localized: "번역 복사됨"), sub: String(localized: "⌘V 로 붙여넣기"))
            HStack(alignment: .top, spacing: 10) {
                if let img = coordinator.latestImage {
                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
                        .frame(width: 150).clipShape(RoundedRectangle(cornerRadius: 9))
                }
                ScrollView {
                    Text(coordinator.latestText.isEmpty ? String(localized: "원문 없음") : coordinator.latestText)
                        .font(.system(size: 12)).foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.frame(maxHeight: 130)
            }
            .padding(11).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 12)
            ScrollView {
                Text(coordinator.latestTranslated)
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(11).frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxHeight: 170)
            .background(Color(red: 0.1, green: 0.11, blue: 0.15)).clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor.opacity(0.35)))
            .padding(.horizontal, 12).padding(.top, 10)
            HStack(spacing: 0) {
                RBtn(String(localized: "⧉ 복사")) { NSPasteboard.general.setString(coordinator.latestTranslated, forType: .string) }
                RBtn(String(localized: "✎ 에디터")) { coordinator.showEditor() }
                RBtn(String(localized: "↻ 다시")) { coordinator.repeatLastArea() }
                RBtn(String(localized: "📌 핀")) { if let img = coordinator.latestImage { coordinator.pinImage(img) } }
            }
            .border(.white.opacity(0.08))
            .padding(.top, 12)
        }
    }

    private var messageBody: some View {
        VStack(spacing: 0) {
            header(dot: "✓", dotColor: .green, title: coordinator.cardTitle, sub: coordinator.cardBody)
            if let img = coordinator.latestImage {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
                    .frame(height: 120).clipShape(RoundedRectangle(cornerRadius: 9))
                    .padding(.horizontal, 12)
            }
            HStack(spacing: 0) {
                RBtn(String(localized: "✎ 에디터")) { coordinator.showEditor() }
                RBtn(String(localized: "닫기")) { coordinator.closeResultCard() }
            }
            .border(.white.opacity(0.08))
            .padding(.top, 12)
        }
    }

    private var errorBody: some View {
        VStack(spacing: 0) {
            header(dot: "!", dotColor: .red, title: coordinator.cardTitle, sub: coordinator.cardBody)
            HStack(spacing: 0) {
                switch coordinator.cardAction {
                case .openScreenRecording:
                    RBtn(String(localized: "설정 열기")) {
                        coordinator.closeResultCard()
                        coordinator.openScreenRecordingSettings()
                    }
                case .retryTranslate:
                    RBtn(String(localized: "다시 시도")) {
                        if let img = coordinator.latestImage {
                            Task { await coordinator.runTranslate(img: img) }
                        } else { coordinator.closeResultCard() }
                    }
                case .openLanguageSettings:
                    RBtn(String(localized: "언어 설정 열기")) {
                        coordinator.closeResultCard()
                        coordinator.openLanguageSettings()
                    }
                case .none:
                    EmptyView()
                }
                RBtn(String(localized: "닫기")) { coordinator.closeResultCard() }
            }
            .border(.white.opacity(0.08))
            .padding(.top, 12)
        }
    }

    private func header(dot: String, dotColor: Color, title: String, sub: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(dot).font(.system(size: 13, weight: .black))
                .frame(width: 22, height: 22).background(dotColor).foregroundColor(.white)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13.5, weight: .bold))
                Text(sub).font(.system(size: 12)).foregroundColor(.secondary)
            }
            Spacer()
            Button("×") { coordinator.closeResultCard() }.buttonStyle(.plain).foregroundColor(.secondary)
        }.padding(14).padding(.bottom, 2)
    }

    private func RBtn(_ t: String, _ a: @escaping () -> Void) -> some View {
        Button(t, action: a).buttonStyle(.plain).font(.system(size: 12.5, weight: .semibold))
            .frame(maxWidth: .infinity).padding(.vertical, 11)
    }
}
