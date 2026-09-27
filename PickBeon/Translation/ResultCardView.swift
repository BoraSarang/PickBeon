import SwiftUI
import AppKit
import UniformTypeIdentifiers

// 헤더 없는 번역 스티커 (330px): accent 좌바 + 원문/번역 + 하단 액션. 3초 자동숨김(에러 제외).
struct ResultCardView: View {
    @ObservedObject var coordinator: AppCoordinator
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                accentBar
                VStack(spacing: 0) {
                    switch coordinator.cardMode {
                    case .translation: translationBody
                    case .message:     messageBody
                    case .error:       errorBody
                    case .progress:    progressBody
                    }
                }
            }
        }
        .frame(width: 330)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel))
        .overlay(RoundedRectangle(cornerRadius: Theme.rPanel).stroke(Theme.line, lineWidth: 1))
        .padding(8)
        .overlay(alignment: .bottom) {
            // [P0-2] 복사 결과 안내 (3초 자동숨김과 무관하게 토스트만 잠깐)
            if let toast = coordinator.copyToast {
                Text(toast)
                    .font(Theme.font(10.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.ok))
                    .padding(.bottom, 10)
                    .transition(.opacity)
            }
        }
        .animation(Theme.hoverFade, value: coordinator.copyToast)
        .overlay(alignment: .topTrailing) {
            if hovering || coordinator.cardMode == .error {
                closeButton
                    .padding(14)
            }
        }
        .onHover { h in
            hovering = h
            coordinator.setCardHovering(h)
        }
        .transition(.scale(scale: 0.96).combined(with: .opacity))
    }

    private var accentBar: some View {
        RoundedRectangle(cornerRadius: 0)
            .fill(accentColor)
            .frame(width: 3)
    }

    private var accentColor: Color {
        switch coordinator.cardMode {
        case .error: return Theme.danger
        case .progress: return Theme.accent.opacity(0.7)
        default: return Theme.accent
        }
    }

    private var closeButton: some View {
        Button {
            coordinator.closeResultCard()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.primary.opacity(0.06)))
        }
        .buttonStyle(.plain)
        .help(String(localized: "닫기 (Esc)"))
    }

    // MARK: 번역
    private var translationBody: some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "번역 복사됨 · ⌘V"))
                    .font(Theme.font(10.5, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary.opacity(0.85))
                if !coordinator.latestText.isEmpty {
                    Text(coordinator.latestText.replacingOccurrences(of: "\n", with: " "))
                        .font(Theme.font(12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Text(coordinator.latestTranslated)
                    .font(Theme.font(13.5, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.row)
            .clipShape(RoundedRectangle(cornerRadius: Theme.rBlock))
            .overlay(RoundedRectangle(cornerRadius: Theme.rBlock).stroke(Theme.transPanelLine, lineWidth: 1))
            .padding(.horizontal, 12)

            if let img = coordinator.latestImage {
                thumbnail(img)
                    .padding(.horizontal, 12)
            }

            actions([
                .init(title: String(localized: "번역 보기"), icon: "text.bubble", prominent: false) { coordinator.showEditor() },
                .init(title: String(localized: "다시"), icon: "arrow.clockwise") { coordinator.repeatLastArea() },
                .init(title: String(localized: "핀"), icon: coordinator.cardPinned ? "pin.fill" : "pin") {
                    coordinator.toggleCardPin()
                },
            ])
        }
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    // MARK: 메시지
    private var messageBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(coordinator.cardTitle.isEmpty ? String(localized: "완료") : coordinator.cardTitle)
                    .font(Theme.font(13.5, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                if !coordinator.cardBody.isEmpty {
                    Text(coordinator.cardBody)
                        .font(Theme.font(12))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)

            if let img = coordinator.latestImage {
                thumbnail(img)
                    .padding(.horizontal, 12)
            }

            actions([
                .init(title: String(localized: "에디터"), icon: "square.and.pencil") { coordinator.showEditor() },
                .init(title: String(localized: "닫기"), icon: "xmark") { coordinator.closeResultCard() },
            ])
        }
        .padding(.bottom, 4)
    }

    // MARK: 진행 중
    /// [FIX] OCR·번역은 수 초~수십 초 걸릴 수 있는데 이전엔 오버레이를 닫은 뒤
    /// 아무 표시 없이 기다리기만 했다("한참 멍때리다"现象). 단계 텍스트로 진행을 알린다.
    private var progressBody: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.8)
                Text(coordinator.cardTitle.isEmpty ? String(localized: "처리 중") : coordinator.cardTitle)
                    .font(Theme.font(13, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            if !coordinator.cardBody.isEmpty {
                Text(coordinator.cardBody)
                    .font(Theme.font(11.5))
                    .foregroundStyle(Theme.textSecondary)
            }
            if let img = coordinator.latestImage {
                HStack(spacing: 9) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 68, height: 46)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.line, lineWidth: 1))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "캡쳐 원본"))
                            .font(Theme.font(11.5, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(String(localized: "완료되면 번역문이 표시됩니다"))
                            .font(Theme.font(10.5))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(8)
                .background(Theme.row)
                .clipShape(RoundedRectangle(cornerRadius: Theme.rBlock))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
    }

    // MARK: 에러
    private var errorBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(coordinator.cardTitle.isEmpty ? String(localized: "오류") : coordinator.cardTitle)
                    .font(Theme.font(13.5, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                if !coordinator.cardBody.isEmpty {
                    Text(coordinator.cardBody)
                        .font(Theme.font(12))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)

            actions(errorActions)
                .padding(.bottom, 4)
        }
    }

    private var errorActions: [CardBtn] {
        var list: [CardBtn] = []
        switch coordinator.cardAction {
        case .openScreenRecording:
            list.append(.init(title: String(localized: "설정 열기"), icon: "gearshape", prominent: true) {
                coordinator.closeResultCard()
                coordinator.openScreenRecordingSettings()
            })
        case .retryTranslate:
            list.append(.init(title: String(localized: "다시 시도"), icon: "arrow.clockwise", prominent: true) {
                if let img = coordinator.latestImage {
                    coordinator.closeResultCard()
                    Task { await coordinator.runTranslate(img: img) }
                } else { coordinator.closeResultCard() }
            })
        case .openLanguageSettings:
            list.append(.init(title: String(localized: "언어 설정"), icon: "globe", prominent: true) {
                coordinator.closeResultCard()
                coordinator.openLanguageSettings()
            })
        case .none:
            break
        }
        list.append(.init(title: String(localized: "닫기"), icon: "xmark") { coordinator.closeResultCard() })
        return list
    }

    // MARK: 썸네일 (드래그 = 이미지 클립보드)
    private func thumbnail(_ img: NSImage) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 84, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(String(localized: "캡쳐 원본"))
                    .font(Theme.font(12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(String(localized: "썸네일을 드래그해 이미지 복사"))
                    .font(Theme.font(11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.surface2))
        }
        .padding(9)
        .background(Theme.row)
        .clipShape(RoundedRectangle(cornerRadius: Theme.rBlock))
        .opacity(0.98)
        .draggable(ImageTransferable(image: img)) {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 44)
                .opacity(0.85)
        }
        .help(String(localized: "드래그하여 이미지를 클립보드로"))
    }

    // MARK: 액션 바
    private func actions(_ btns: [CardBtn]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(btns.enumerated()), id: \.offset) { i, b in
                if i > 0 {
                    Rectangle().fill(Theme.line).frame(width: 1, height: 28)
                }
                FooterButton(title: b.title, systemImage: b.icon, prominent: b.prominent, action: b.action)
            }
        }
        .background(Theme.surface2.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: Theme.rBlock))
        .padding(.horizontal, 12)
    }
}

private struct CardBtn {
    let title: String
    let icon: String
    var prominent = false
    let action: () -> Void
}

// MARK: - 이미지 드래그 payload
struct ImageTransferable: Transferable {
    let image: NSImage
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            PasteboardService.pngData(of: item.image) ?? Data()
        }
        DataRepresentation(importedContentType: .png) { data in
            ImageTransferable(image: NSImage(data: data) ?? NSImage())
        }
    }
}
