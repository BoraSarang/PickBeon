import AppKit
import CoreImage

/// 블러/모자이크 감열 렌더러.
///
/// [P0-3] 과거 구현의 두 결함:
///  1. 좌표 뒤집힘. 주석 좌표는 정규화 top-left 원점이지만, 합성 시 AppKit 하단원점
///     (y = (1 - n.y) * h) 으로 변환해 `region` 을 만들었다. 그 region 을 그대로
///     `CGImage.cropping(to:)` 에 넣었는데 CGImage 도 top-left 원점이라
///     → **세로 대칭된 영역이 감춰졌다.** (민감정보 노출 위험)
///  2. 미리보기 ≠ 결과. 블러 preview 는 `.ultraThinMaterial`(이미지 아래가 아니라
///     데스크톱 배경과 blend), 모자이크 preview 는 가짜 checkerboard. 실제 합성은
///     CoreImage 라 사용자가 본 것과 저장된 것이 달랐다.
///
/// 해결: 정규화 top-left 좌표 한 벌만 받아 모든 컨텍스트(에디터 미리보기 / 복사·핀 합성)에서
/// 같은 함수를 쓴다. CGImage 도 top-left 원점이므로 **y 반전이 전혀 필요 없다.**
enum Redactor {
    enum Style { case blur, mosaic }

    struct Output {
        let image: NSImage
        /// 실제 감춰진 범위 (정규화 top-left). 블러는 가장자리 품질 확보용 pad 를 포함하므로
        /// 요청 rect 보다 클 수 있다.
        let rect: CGRect
    }

    static func apply(_ n: CGRect, in image: NSImage, style: Style) -> Output? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let full = CGRect(x: 0, y: 0, width: cg.width, height: cg.height)

        // 정규화 top-left → CGImage 픽셀. 원점이 같으므로 y 그대로.
        let raw = CGRect(x: n.minX * full.width, y: n.minY * full.height,
                         width: n.width * full.width, height: n.height * full.height)
        let target = raw.intersection(full)
        guard target.width > 2, target.height > 2 else { return nil }

        switch style {
        case .blur:
            // 가장자리 검은 테두리 방지: pad 만큼 넓게 샘플 → 블러 → 다시 중앙으로 크롭.
            let radius = max(4, min(target.width, target.height) * 0.05)
            return blur(target: target, full: full, cg: cg, radius: radius)
        case .mosaic:
            let block = max(4, Int(min(target.width, target.height) / 20))
            return mosaic(target: target, full: full, cg: cg, block: block)
        }
    }

    // MARK: - Blur

    private static func blur(target: CGRect, full: CGRect, cg: CGImage, radius: CGFloat) -> Output? {
        let pad = radius * 2
        let sample = target.insetBy(dx: -pad, dy: -pad).intersection(full)
        guard sample.width > 2, sample.height > 2,
              let sampleCg = cg.cropping(to: sample.integral) else { return nil }

        let ci = CIImage(cgImage: sampleCg)
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
        filter.setValue(ci, forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        guard let out = filter.outputImage?.cropped(to: ci.extent) else { return nil }
        // createCGImage 출력도 top-left 원점 → 방향 보존.
        guard let outCg = CIContext().createCGImage(out, from: ci.extent) else { return nil }
        return Output(image: NSImage(cgImage: outCg, size: CGSize(width: sampleCg.width, height: sampleCg.height)), rect: sample.toNormalized(in: full))
    }

    // MARK: - Mosaic

    private static func mosaic(target: CGRect, full: CGRect, cg: CGImage, block: Int) -> Output? {
        // CIPixellate 도 가장자리 샘플이 필요하므로 pad 후 크롭.
        let pad = CGFloat(block) * 2
        let sample = target.insetBy(dx: -pad, dy: -pad).intersection(full)
        guard sample.width > 2, sample.height > 2,
              let sampleCg = cg.cropping(to: sample.integral) else { return nil }

        let ci = CIImage(cgImage: sampleCg)
        guard let filter = CIFilter(name: "CIPixellate") else { return nil }
        filter.setValue(ci, forKey: kCIInputImageKey)
        filter.setValue(Float(block), forKey: kCIInputScaleKey)
        guard let out = filter.outputImage?.cropped(to: ci.extent) else { return nil }
        guard let outCg = CIContext().createCGImage(out, from: ci.extent) else { return nil }
        return Output(image: NSImage(cgImage: outCg, size: CGSize(width: sampleCg.width, height: sampleCg.height)), rect: sample.toNormalized(in: full))
    }
}

private extension CGRect {
    /// 픽셀 rect → 정규화(0...1) top-left.
    func toNormalized(in full: CGRect) -> CGRect {
        CGRect(x: minX / full.width, y: minY / full.height,
               width: width / full.width, height: height / full.height)
    }
}
