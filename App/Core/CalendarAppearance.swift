import Foundation

enum ThemeMode: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { switch self { case .system: return "跟随系统"; case .light: return "白昼"; case .dark: return "暗夜" } }
}

enum AccentPalette: String, Codable, CaseIterable, Identifiable {
    case lavender, rose, sky, mint
    var id: String { rawValue }
    var label: String { switch self { case .lavender: return "暮紫"; case .rose: return "樱粉"; case .sky: return "雾蓝"; case .mint: return "薄荷" } }
}

struct CalendarSticker: Codable, Identifiable, Equatable {
    var id = UUID()
    var imageName: String
    var x: Double = 0.8
    var y: Double = 0.75
    var width: Double = 0.28
    var rotation: Double = 0
    var opacity: Double = 0.85
}

struct CalendarAppearance: Codable, Equatable {
    var mode: ThemeMode = .system
    var accent: AccentPalette = .lavender
    var nightPaws: Bool = true
    var background = BackgroundStyle(imageName: nil, showsImage: false, veil: 0.48, blur: 0)
    // Back-to-front order. Bring to front is an action, never a persistent switch.
    var stickers: [CalendarSticker] = []
    var referencedImages: Set<String> {
        Set(stickers.map(\.imageName) + [background.imageName].compactMap { $0 })
    }
    mutating func bringToFront(_ id: UUID) {
        guard let index = stickers.firstIndex(where: { $0.id == id }) else { return }
        stickers.append(stickers.remove(at: index))
    }
    mutating func remapImage(_ old: String, to replacement: String) {
        if background.imageName == old { background.imageName = replacement }
        for index in stickers.indices where stickers[index].imageName == old { stickers[index].imageName = replacement }
    }
    func validated() throws {
        try DiaryRules.validateStyle(background)
        guard stickers.count <= 12, Set(stickers.map(\.id)).count == stickers.count else {
            throw DiaryFailure.message("月历图片图层数量或编号不正确。")
        }
        for layer in stickers {
            guard DiaryRules.safeImageName(layer.imageName),
                  layer.x.isFinite, (0...1).contains(layer.x), layer.y.isFinite, (0...1).contains(layer.y),
                  layer.width.isFinite, (0.08...0.95).contains(layer.width),
                  layer.rotation.isFinite, (-180...180).contains(layer.rotation),
                  layer.opacity.isFinite, (0...1).contains(layer.opacity) else {
                throw DiaryFailure.message("月历图片的位置、大小或透明度不正确。")
            }
        }
    }
}

enum MonthLayout {
    static let count = 300 * 12
    static func index(of date: Date) -> Int {
        let parts = DayKey.calendar.dateComponents([.year, .month], from: date)
        return min(count - 1, max(0, ((parts.year ?? 2026) - 1900) * 12 + (parts.month ?? 1) - 1))
    }
    static func date(at index: Int) -> Date {
        let value = min(count - 1, max(0, index))
        return DayKey.date(String(format: "%04d-%02d-01", 1900 + value / 12, value % 12 + 1))!
    }
    static func snappedOffset(_ proposed: Double, stride: Double, maximum: Double) -> Double {
        guard stride > 0, stride.isFinite, proposed.isFinite, maximum.isFinite else { return 0 }
        return min(max(0, maximum), max(0, (proposed / stride).rounded() * stride))
    }
    static func opacity(distance: Double, stride: Double) -> Double {
        max(0.22, 1 - min(1, abs(distance) / max(1, stride)) * 0.78)
    }
}
