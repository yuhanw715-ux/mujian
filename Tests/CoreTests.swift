import Foundation

private struct TestFailure: Error { let description: String }

@main
enum CoreTests {
    static var checks = 0
    static func check(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        guard try condition() else { throw TestFailure(description: message) }
        checks += 1
    }
    static func rejects(_ message: String, _ operation: () throws -> Void) throws {
        do { try operation() } catch { checks += 1; return }
        throw TestFailure(description: message)
    }
    static func main() throws {
        try dateTests()
        try textTests()
        try diaryTests()
        try backupTests()
        print("PASS: \(checks) diary/date/TXT/backup checks. Only synthetic test text was used.")
    }

    static func dateTests() throws {
        try check(DayKey.dates(inFilename: "Miu_2026-10-08.txt") == ["2026-10-08"], "ISO filename date")
        try check(DayKey.dates(inFilename: "日记_2026年9月2日.txt") == ["2026-09-02"], "Chinese filename date")
        try check(DayKey.dates(inFilename: "我的_20261008.txt") == ["2026-10-08"], "Compact filename date")
        try check(DayKey.dates(inFilename: "2026_10_8_日记.txt") == ["2026-10-08"], "Underscore date")
        try check(DayKey.dates(inFilename: "2026.10.8.txt") == ["2026-10-08"], "Dot date")
        try check(DayKey.dates(inFilename: "还没起名.txt").isEmpty, "Missing date must require selection")
        try check(DayKey.dates(inFilename: "09-22.txt").isEmpty, "Missing year must require selection")
        try check(DayKey.dates(inFilename: "2026-02-29.txt").isEmpty, "Do not silently roll invalid date forward")
        try check(DayKey.dates(inFilename: "2024-02-29.txt") == ["2024-02-29"], "Leap date")
        try check(DayKey.dates(inFilename: "2026-10-08至2026-10-09.txt").count == 2, "Ambiguous range must require selection")
        try check(DayKey.dates(inFilename: "2026100822.txt").isEmpty, "Do not extract embedded long digits")
        try check(DayKey.date("2026-13-01") == nil, "Invalid month")
        try check(DayKey.date("2026-04-31") == nil, "Invalid day")
        try check(DayKey.date("2026-1-1") == nil, "Keys must be canonical")
        let september = DayKey.monthCells(DayKey.date("2026-09-01")!)
        try check(september.count == 35 && september[0] == nil && september[2] == "2026-09-01", "Sunday-first calendar alignment")
        try check(september.compactMap { $0 }.count == 30, "All days once")
        let sixRows = DayKey.monthCells(DayKey.date("2026-08-01")!)
        try check(sixRows.count == 42, "Six-row month")
        let fourRows = DayKey.monthCells(DayKey.date("2026-02-01")!)
        try check(fourRows.count == 28, "Four-row month")
    }

    static func textTests() throws {
        let original = "  第一段（测试文字）\n\n第二段 🌙\n最后一行\n"
        try check(try DiaryRules.decodeText(Data(original.utf8)) == original, "Preserve paragraphs, whitespace and emoji")
        let bom = Data([0xEF, 0xBB, 0xBF]) + Data("第一行\r\n\r\n第二行\r".utf8)
        try check(try DiaryRules.decodeText(bom) == "第一行\n\n第二行\n", "Normalize BOM and Windows newlines")
        let le = Data([0xFF, 0xFE]) + original.data(using: .utf16LittleEndian)!
        let be = Data([0xFE, 0xFF]) + original.data(using: .utf16BigEndian)!
        try check(try DiaryRules.decodeText(le) == original, "UTF-16 LE")
        try check(try DiaryRules.decodeText(be) == original, "UTF-16 BE")
        #if canImport(Darwin)
        let legacy = "中文测试".data(using: TextEncodingChoice.gb18030.encoding)!
        try check(try DiaryRules.decodeText(legacy) == "中文测试", "Windows GB18030 auto-detection")
        try check(try DiaryRules.decodeText(legacy, choice: .gb18030) == "中文测试", "Explicit legacy encoding")
        #endif
        try rejects("Empty TXT must be rejected") { _ = try DiaryRules.decodeText(Data(" \n\t".utf8)) }
        try rejects("Binary NUL content must be rejected") { _ = try DiaryRules.decodeText(Data([0, 1, 2, 3])) }
        try rejects("Oversized TXT must be rejected") { _ = try DiaryRules.decodeText(Data(repeating: 65, count: DiaryRules.maxTextBytes + 1)) }
        try check(DiaryRules.inferredAuthor(filename: "MIU_20261008.txt") == .miu, "Case-insensitive Miu author hint")
    }

    static func diaryTests() throws {
        var lib = DiaryLibrary()
        let now = Date(timeIntervalSince1970: 1_790_000_000.123)
        for i in 0..<5 {
            lib.entries.append(DiaryEntry(day: "2026-10-08", author: i == 0 ? .me : .miu, title: "测试\(i)", body: "虚构测试正文 \(i)", createdAt: now, updatedAt: now))
        }
        try DiaryRules.validateLibrary(lib)
        try check(lib.entries(on: "2026-10-08").count == 5, "More than two entries per day")
        try check(lib.entries(on: "2026-10-08").first?.author == .me, "My diary before Miu diary")
        try check(DiaryRules.isDuplicate(body: "虚构测试正文 0", day: "2026-10-08", author: .me, in: lib), "Duplicate import detection")
        try check(!DiaryRules.isDuplicate(body: "虚构测试正文 0", day: "2026-10-09", author: .me, in: lib), "Same text on another date is allowed")
        var incoming = lib
        incoming.entries[0].body = "更新后的测试文字"
        incoming.entries[0].updatedAt = now.addingTimeInterval(0.4)
        incoming.entries[1].deletedAt = now.addingTimeInterval(1)
        incoming.entries[1].updatedAt = now.addingTimeInterval(1)
        let merged = DiaryRules.merging(incoming, into: lib)
        try check(merged.activeEntries.count == 4, "Newer tombstone is preserved")
        try check(merged.entries.first { $0.id == lib.entries[0].id }?.body == "更新后的测试文字", "Newer body wins")
        try check(DiaryRules.merging(lib, into: merged).activeEntries.count == 4, "Old backup must not resurrect newer deletion")
        try check(DiaryRules.merging(incoming, into: merged).entries.count == 5, "Repeated restore is idempotent")
        let roundTrip = try DiaryCodec.decode(DiaryLibrary.self, from: DiaryCodec.encode(merged))
        try check(abs(roundTrip.entries[0].updatedAt.timeIntervalSince(merged.entries[0].updatedAt)) < 0.001, "Subsecond timestamps survive backup")
        var invalid = lib
        invalid.entries.append(lib.entries[0])
        try rejects("Reject duplicate IDs") { try DiaryRules.validateLibrary(invalid) }
        var entry = lib.entries[0]; entry.body = "  "
        try rejects("Reject blank body") { try DiaryRules.validateEntry(entry) }
    }

    static func backupTests() throws {
        let imageName = UUID().uuidString + ".jpg"
        var library = DiaryLibrary()
        library.entries = [DiaryEntry(day: "2026-10-08", author: .miu, title: "测试", body: "备份测试\n\n只使用虚构内容。")]
        library.defaultBackground.imageName = imageName
        let draft = DiaryDraft(day: "2026-10-09", title: "测试草稿", body: "还未写完的测试。")
        let backup = DiaryBackup(library: library, drafts: [draft], images: [imageName: Data([1, 2, 3])])
        let data = try DiaryCodec.encode(backup)
        let decoded = try DiaryRules.decodeBackup(data)
        try check(decoded.library.entries[0].body == backup.library.entries[0].body, "Backup body round trip")
        try check(decoded.drafts[0].body == draft.body, "Draft backup round trip")
        try check(decoded.images[imageName] == Data([1, 2, 3]), "Image bytes round trip")
        var missing = backup; missing.images = [:]
        try rejects("Missing referenced image must not restore") { _ = try DiaryRules.decodeBackup(DiaryCodec.encode(missing)) }
        var traversal = backup; traversal.images["../library.json"] = Data([1])
        try rejects("Reject path traversal in image names") { _ = try DiaryRules.decodeBackup(DiaryCodec.encode(traversal)) }
        var future = backup; future.schemaVersion = 2
        try rejects("Reject unsupported schema without overwriting") { _ = try DiaryRules.decodeBackup(DiaryCodec.encode(future)) }
        var unrelated = backup; unrelated.documentType = "other.app"
        try rejects("Reject unrelated JSON") { _ = try DiaryRules.decodeBackup(DiaryCodec.encode(unrelated)) }
        var invalidStyle = backup; invalidStyle.library.defaultBackground.veil = -1
        try rejects("Reject invalid image opacity") { _ = try DiaryRules.decodeBackup(DiaryCodec.encode(invalidStyle)) }
        try check(!DiaryRules.safeImageName("../../outside.jpg"), "Reject non-UUID file basename")
    }
}
