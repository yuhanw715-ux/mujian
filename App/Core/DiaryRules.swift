import Foundation
import CoreFoundation

enum DayKey {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.firstWeekday = 1
        return calendar
    }
    static func make(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    static func date(_ key: String) -> Date? {
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3, (1...9999).contains(p[0]), (1...12).contains(p[1]), (1...31).contains(p[2]) else { return nil }
        guard let date = calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: 12)) else { return nil }
        return make(date) == key ? date : nil
    }
    static func monthStart(_ date: Date) -> Date {
        let c = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: DateComponents(year: c.year, month: c.month, day: 1, hour: 12))!
    }
    static func monthCells(_ month: Date) -> [String?] {
        let first = monthStart(month)
        let leading = calendar.component(.weekday, from: first) - 1
        let count = calendar.range(of: .day, in: .month, for: first)!.count
        var cells = Array<String?>(repeating: nil, count: leading)
        for i in 0..<count { cells.append(make(calendar.date(byAdding: .day, value: i, to: first)!)) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }
    static func dates(inFilename filename: String) -> [String] {
        let patterns = [#"(?<!\d)((?:19|20|21)\d{2})[-_./年](\d{1,2})[-_./月](\d{1,2})日?(?!\d)"#,
                        #"(?<!\d)((?:19|20|21)\d{2})(\d{2})(\d{2})(?!\d)"#]
        var result = Set<String>()
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(filename.startIndex..., in: filename)
            for match in regex.matches(in: filename, range: range) {
                let parts = (1...3).compactMap { i -> Int? in
                    guard let range = Range(match.range(at: i), in: filename) else { return nil }
                    return Int(filename[range])
                }
                guard parts.count == 3 else { continue }
                let key = String(format: "%04d-%02d-%02d", parts[0], parts[1], parts[2])
                if date(key) != nil { result.insert(key) }
            }
        }
        return result.sorted()
    }
}

enum TextEncodingChoice: String, CaseIterable, Identifiable {
    case auto, utf8, utf16LE, utf16BE, gb18030
    var id: String { rawValue }
    var label: String {
        switch self {
        case .auto: return "自动识别"
        case .utf8: return "UTF-8"
        case .utf16LE: return "UTF-16 LE"
        case .utf16BE: return "UTF-16 BE"
        case .gb18030: return "GB18030 / GBK"
        }
    }
    var encoding: String.Encoding {
        switch self {
        case .auto, .utf8: return .utf8
        case .utf16LE: return .utf16LittleEndian
        case .utf16BE: return .utf16BigEndian
        case .gb18030:
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        }
    }
}

enum DiaryRules {
    static let maxTextBytes = 5 * 1024 * 1024
    static let maxBackupBytes = 150 * 1024 * 1024
    static func decodeText(_ data: Data, choice: TextEncodingChoice = .auto) throws -> String {
        guard data.count <= maxTextBytes else { throw DiaryFailure.message("这份 TXT 超过 5 MB，请先拆成较小的文件。") }
        var text: String?
        if choice == .auto {
            if data.starts(with: [0xFF, 0xFE]) { text = String(data: data, encoding: .utf16LittleEndian) }
            else if data.starts(with: [0xFE, 0xFF]) { text = String(data: data, encoding: .utf16BigEndian) }
            else { text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: TextEncodingChoice.gb18030.encoding) }
        } else { text = String(data: data, encoding: choice.encoding) }
        guard var value = text, !value.contains("\0") else { throw DiaryFailure.message("暂时读不懂文件编码，请换一种编码再看看。") }
        if value.hasPrefix("\u{FEFF}") { value.removeFirst() }
        value = value.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw DiaryFailure.message("这份文件是空白的，还没有可以收藏的文字。") }
        return value
    }
    static func inferredAuthor(filename: String) -> DiaryAuthor {
        filename.range(of: "miu", options: .caseInsensitive) == nil ? .me : .miu
    }
    static func validateEntry(_ entry: DiaryEntry) throws {
        guard DayKey.date(entry.day) != nil else { throw DiaryFailure.message("日记日期不正确。") }
        guard !entry.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw DiaryFailure.message("先写一点内容，再收藏这篇日记吧。") }
        guard entry.body.utf8.count <= maxTextBytes, entry.title.count <= 200 else { throw DiaryFailure.message("这篇日记或标题过长。") }
    }
    static func safeImageName(_ name: String) -> Bool {
        guard name.hasSuffix(".jpg") else { return false }
        return UUID(uuidString: String(name.dropLast(4))) != nil
    }
    static func validateStyle(_ style: BackgroundStyle) throws {
        guard style.veil.isFinite, (0...1).contains(style.veil), style.blur.isFinite, (0...20).contains(style.blur),
              style.imageName.map(safeImageName) ?? true else { throw DiaryFailure.message("背景设置格式不正确。") }
    }
    static func validateLibrary(_ library: DiaryLibrary) throws {
        guard library.schemaVersion == 1 else { throw DiaryFailure.message("这个备份需要其他版本的暮笺，请保留原文件。") }
        guard Set(library.entries.map(\.id)).count == library.entries.count else { throw DiaryFailure.message("文件含有重复的日记编号。") }
        for entry in library.entries { try validateEntry(entry) }
        try validateStyle(library.defaultBackground)
        for (day, style) in library.dayBackgrounds {
            guard DayKey.date(day) != nil else { throw DiaryFailure.message("背景日期不正确。") }
            try validateStyle(style)
        }
        guard library.readerFontSize.isFinite, (14...30).contains(library.readerFontSize) else { throw DiaryFailure.message("阅读字号不正确。") }
    }
    static func decodeBackup(_ data: Data) throws -> DiaryBackup {
        guard data.count <= maxBackupBytes else { throw DiaryFailure.message("备份超过 150 MB，暂时无法一次读取。") }
        let backup = try DiaryCodec.decode(DiaryBackup.self, from: data)
        guard backup.documentType == "app.miu.mujian.backup", backup.schemaVersion == 1 else { throw DiaryFailure.message("这不是暮笺支持的备份文件。") }
        try validateLibrary(backup.library)
        guard Set(backup.drafts.map(\.id)).count == backup.drafts.count else { throw DiaryFailure.message("备份中的草稿编号重复。") }
        for draft in backup.drafts {
            guard DayKey.date(draft.day) != nil, draft.body.utf8.count <= maxTextBytes, draft.title.count <= 200 else { throw DiaryFailure.message("备份中的草稿格式不正确。") }
        }
        for (name, bytes) in backup.images {
            guard safeImageName(name), !bytes.isEmpty, bytes.count <= 12 * 1024 * 1024 else { throw DiaryFailure.message("备份中的图片格式不正确。") }
        }
        guard backup.library.referencedImages.isSubset(of: Set(backup.images.keys)) else { throw DiaryFailure.message("备份缺少背景图片，请保留完整备份。") }
        return backup
    }
    static func merging(_ incoming: DiaryLibrary, into current: DiaryLibrary) -> DiaryLibrary {
        var result = current
        var byID = Dictionary(uniqueKeysWithValues: current.entries.map { ($0.id, $0) })
        for entry in incoming.entries {
            if let old = byID[entry.id], old.updatedAt >= entry.updatedAt { continue }
            byID[entry.id] = entry
        }
        result.entries = Array(byID.values).sorted { $0.createdAt < $1.createdAt }
        for (day, style) in incoming.dayBackgrounds where result.dayBackgrounds[day] == nil { result.dayBackgrounds[day] = style }
        return result
    }
    static func isDuplicate(body: String, day: String, author: DiaryAuthor, in library: DiaryLibrary) -> Bool {
        library.activeEntries.contains { $0.day == day && $0.author == author && $0.body == body }
    }
}
