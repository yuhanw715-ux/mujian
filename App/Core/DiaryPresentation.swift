import Foundation

extension DiaryEntry {
    // Use these values for ALL passive previews. Never blur or visually cover real
    // Miu text: that would still expose it to accessibility and search results.
    var overviewTitle: String { author == .miu ? "Miu 留下的一页" : displayTitle }
    var overviewExcerpt: String { author == .miu ? "正文轻轻收好，等你翻开。" : excerpt }
    var momentLabel: String? { author == .me ? (writingMoment?.label ?? "未标记") : nil }
    func matchesOverviewSearch(_ query: String) -> Bool {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return true }
        let dateQuery = value.replacingOccurrences(of: ".", with: "-").replacingOccurrences(of: "/", with: "-")
        if day.contains(dateQuery) || author.label.localizedCaseInsensitiveContains(value) { return true }
        guard author == .me else { return false }
        return title.localizedCaseInsensitiveContains(value) || body.localizedCaseInsensitiveContains(value) ||
            (momentLabel?.localizedCaseInsensitiveContains(value) ?? false)
    }
}

enum DiaryBrowseAuthor: String, CaseIterable, Identifiable {
    case all, me, miu
    var id: String { rawValue }
    var label: String { switch self { case .all: return "全部"; case .me: return "小暮暮"; case .miu: return "Miu" } }
    func includes(_ entry: DiaryEntry) -> Bool { self == .all || rawValue == entry.author.rawValue }
}

struct DiaryDayGroup: Identifiable {
    let day: String
    let entries: [DiaryEntry]
    var id: String { day }
    var mine: [DiaryEntry] { entries.filter { $0.author == .me } }
    var miu: [DiaryEntry] { entries.filter { $0.author == .miu } }
    var hasDifferentCounts: Bool { mine.count != miu.count }
    static func grouped(_ entries: [DiaryEntry]) -> [DiaryDayGroup] {
        Dictionary(grouping: entries.filter { $0.deletedAt == nil }, by: \.day)
            .map { day, entries in DiaryDayGroup(day: day, entries: entries.sorted { $0.createdAt < $1.createdAt }) }
            .sorted { $0.day > $1.day }
    }
    func matches(author: DiaryBrowseAuthor, query: String, differencesOnly: Bool) -> Bool {
        (!differencesOnly || hasDifferentCounts) && entries.contains { author.includes($0) && $0.matchesOverviewSearch(query) }
    }
}
