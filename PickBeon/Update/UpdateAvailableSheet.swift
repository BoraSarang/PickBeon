import SwiftUI
import AppKit

// 릴리스 노트: 줄 단위 블록 + inlineOnly (전체 마크다운 파싱 금지 — 한 덩어리 붙음 방지)
enum ReleaseNotesRenderer {
    static func lines(_ markdown: String) -> [(text: AttributedString, isBlockHeader: Bool)] {
        markdown
            .components(separatedBy: .newlines)
            .map { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let isHeader = trimmed.hasPrefix("#")
                return (styledInline(trimmed, size: isHeader ? 13 : 12, bold: isHeader), isHeader)
            }
            .filter { !$0.text.characters.isEmpty }
    }

    static func styledInline(_ s: String, size: CGFloat, bold: Bool = false) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace)
        var attr = (try? AttributedString(markdown: s, options: options)) ?? AttributedString(s)
        for run in attr.runs {
            var font = Font.system(size: size)
            let intent = run.inlinePresentationIntent
            if bold || intent?.contains(.stronglyEmphasized) == true { font = font.bold() }
            if intent?.contains(.emphasized) == true { font = font.italic() }
            if intent?.contains(.code) == true {
                font = Font.system(size: size, design: .monospaced)
            }
            attr[run.range].font = font
        }
        return attr
    }
}

struct ReleaseNotesView: View {
    let notes: String
    var body: some View {
        let blocks = ReleaseNotesRenderer.lines(notes)
        if blocks.isEmpty {
            Text(String(localized: "릴리스 노트가 없습니다"))
                .font(Theme.font(12))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, b in
                        // View.font()를 붙이지 않는다 — run 폰트 유지
                        Text(b.text)
                            .foregroundStyle(b.isBlockHeader ? Theme.textPrimary : Theme.textPrimary.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
        }
    }
}

// 업데이트 시트 — 설정 경로(.dismiss)와 팝오버 전용 창(onClose) 공용
struct UpdateAvailableSheet: View {
    let tag: String
    let htmlURL: String
    let notes: String
    var onOpenRelease: (() -> Void)? = nil
    var onClose: (() -> Void)? = nil

    private var close: () -> Void {
        { if let onClose { onClose() } else { NSApp.keyWindow?.sheetParent?.endSheet(NSApp.keyWindow!) } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "새 버전이 있습니다"))
                        .font(Theme.font(17, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(String(format: String(localized: "현재 %@ → %@"), ReleaseChecker.currentVersion, tag))
                        .font(Theme.font(12))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "릴리스 노트"))
                    .font(Theme.font(12, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                ReleaseNotesView(notes: notes)
                    .frame(maxHeight: 160)
                    .background(Theme.surface2.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.rBlock))
                    .overlay(RoundedRectangle(cornerRadius: Theme.rBlock).stroke(Theme.line, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "설치 방법"))
                    .font(Theme.font(12, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                Text(String(localized: "릴리스 페이지에서 압축을 내려받아 앱을 교체합니다. 첫 실행이 막히면 우클릭 → 열기를 사용하세요."))
                    .font(Theme.font(12))
                    .foregroundStyle(Theme.textPrimary)
            }

            HStack {
                Button(String(localized: "닫기")) { close() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    if let onOpenRelease { onOpenRelease() }
                    else if let url = URL(string: htmlURL) { NSWorkspace.shared.open(url) }
                    close()
                } label: {
                    Label(String(localized: "릴리스 열기"), systemImage: "safari")
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }
        }
        .padding(20)
        .frame(width: 420)
        .background(Theme.bg)
    }
}
