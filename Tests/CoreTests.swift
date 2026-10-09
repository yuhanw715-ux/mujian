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
        try appearanceTests()
        try navigationTests()
        try importTests()
        try presentationTests()
        try writingMomentTests()
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
        var future = backup; future.schemaVersion = 99
        try rejects("Reject unsupported schema without overwriting") { _ = try DiaryRules.decodeBackup(DiaryCodec.encode(future)) }
        var unrelated = backup; unrelated.documentType = "other.app"
        try rejects("Reject unrelated JSON") { _ = try DiaryRules.decodeBackup(DiaryCodec.encode(unrelated)) }
        var invalidStyle = backup; invalidStyle.library.defaultBackground.veil = -1
        try rejects("Reject invalid image opacity") { _ = try DiaryRules.decodeBackup(DiaryCodec.encode(invalidStyle)) }
        try check(!DiaryRules.safeImageName("../../outside.jpg"), "Reject non-UUID file basename")
    }

    static func appearanceTests() throws {
        var oldLibrary = DiaryLibrary()
        oldLibrary.entries = [DiaryEntry(day: "2026-10-09", author: .me, title: "迁移测试", body: "旧版本的虚构正文\n\n保留空行。")]
        oldLibrary.entries[0].createdAt = Date(timeIntervalSince1970: 1_790_000_000)
        oldLibrary.entries[0].updatedAt = Date(timeIntervalSince1970: 1_790_000_100)
        var object = try JSONSerialization.jsonObject(with: DiaryCodec.encode(oldLibrary)) as! [String: Any]
        object["schemaVersion"] = 1; object.removeValue(forKey: "appearance")
        let migrated = try DiaryCodec.decode(DiaryLibrary.self, from: JSONSerialization.data(withJSONObject: object))
        try check(migrated.entries == oldLibrary.entries, "Migration preserves diaries and timestamps")
        try check(migrated.schemaVersion == 3 && migrated.appearance == CalendarAppearance(), "Old library gets safe appearance defaults")
        var oldBackup = try JSONSerialization.jsonObject(with: DiaryCodec.encode(DiaryBackup(library: oldLibrary, drafts: [], images: [:]))) as! [String: Any]
        oldBackup["library"] = object; oldBackup["schemaVersion"] = 1
        let restored = try DiaryRules.decodeBackup(JSONSerialization.data(withJSONObject: oldBackup))
        try check(restored.library.entries == migrated.entries, "Version 1 backup remains restorable")
        object["schemaVersion"] = 99
        try rejects("Future local schema must not load as blank library") { _ = try DiaryCodec.decode(DiaryLibrary.self, from: JSONSerialization.data(withJSONObject: object)) }

        let png = UUID().uuidString + ".png"
        let jpg = UUID().uuidString + ".jpg"
        try check(DiaryRules.safeImageName(png), "Transparent PNG filenames accepted")
        try check(!DiaryRules.safeImageName("../" + png), "PNG cannot escape image directory")
        var art = CalendarAppearance()
        let a = CalendarSticker(imageName: png)
        let b = CalendarSticker(imageName: jpg)
        let c = CalendarSticker(imageName: png)
        art.stickers = [a, b, c]
        art.mode = .dark; art.accent = .mint; art.background.imageName = png
        art.bringToFront(a.id)
        try check(art.stickers.map(\.id) == [b.id, c.id, a.id], "Bring to front preserves other relative ordering")
        art.bringToFront(b.id)
        try check(art.stickers.map(\.id) == [c.id, a.id, b.id], "Most recent bring-to-front action wins")
        art.bringToFront(b.id); art.bringToFront(UUID())
        try check(art.stickers.count == 3 && art.stickers.last?.id == b.id, "Repeated or missing IDs never duplicate layers")
        let replacement = UUID().uuidString + ".png"
        art.remapImage(png, to: replacement)
        try check(art.background.imageName == replacement && art.stickers.first?.imageName == replacement, "Image collision remaps background and stickers")
        try check(art.referencedImages == Set([replacement, jpg]), "All image references included once")
        var library = DiaryLibrary(); library.appearance = art
        let appearanceBackup = DiaryBackup(library: library, drafts: [], images: [replacement: Data([1, 2]), jpg: Data([3, 4])])
        let decoded = try DiaryRules.decodeBackup(DiaryCodec.encode(appearanceBackup))
        try check(decoded.library.appearance == art, "Theme, positions, opacity and stacking survive backup")
        var missing = appearanceBackup; missing.images.removeValue(forKey: jpg)
        try rejects("Missing sticker image prevents partial restore") { _ = try DiaryRules.decodeBackup(DiaryCodec.encode(missing)) }
        var invalid = art; invalid.stickers[0].width = 2
        try rejects("Oversized layer must be rejected") { try invalid.validated() }
        invalid = art; invalid.stickers[0].x = .nan
        try rejects("NaN image position must be rejected") { try invalid.validated() }
        var local = DiaryLibrary(); local.appearance.accent = .rose
        try check(DiaryRules.merging(library, into: local).appearance.accent == .rose, "Merge keeps local theme settings")

        try check(MonthLayout.index(of: DayKey.date("1900-01-01")!) == 0, "First supported month")
        try check(DayKey.make(MonthLayout.date(at: 3599)) == "2199-12-01", "Last supported month")
        try check(DayKey.make(MonthLayout.date(at: MonthLayout.index(of: DayKey.date("2026-10-09")!))) == "2026-10-01", "Month index round trip")
        try check(MonthLayout.snappedOffset(49, stride: 100, maximum: 900) == 0, "Snap backward to closest month")
        try check(MonthLayout.snappedOffset(51, stride: 100, maximum: 900) == 100, "Snap forward to closest month")
        try check(MonthLayout.snappedOffset(-50, stride: 100, maximum: 900) == 0, "Snap clamps before first month")
        try check(MonthLayout.snappedOffset(980, stride: 100, maximum: 900) == 900, "Snap clamps after last month")
        try check(MonthLayout.opacity(distance: 0, stride: 100) == 1, "Centered month is fully opaque")
        try check(abs(MonthLayout.opacity(distance: 200, stride: 100) - 0.22) < 0.001, "Adjacent month never becomes invisible")
    }

    static func presentationTests() throws {
        let secretTitle = "SYNTHETIC_PRIVATE_TITLE_907"
        let secretBody = "SYNTHETIC_PRIVATE_BODY_681"
        let miu = DiaryEntry(day: "2026-10-09", author: .miu, title: secretTitle, body: secretBody)
        try check(!miu.overviewTitle.contains(secretTitle), "Miu title does not leak into overview")
        try check(!miu.overviewExcerpt.contains(secretBody), "Miu excerpt does not leak into overview")
        try check(!miu.matchesOverviewSearch(secretTitle), "Hidden Miu title is not searchable from overview")
        try check(!miu.matchesOverviewSearch(secretBody), "Hidden Miu body is not searchable from overview")
        try check(miu.matchesOverviewSearch("2026.10.09"), "Miu remains findable by dotted date")
        try check(miu.matchesOverviewSearch("2026/10/09"), "Slashed dates are searchable")
        try check(miu.matchesOverviewSearch("miu"), "Miu remains findable by author")
        try check(miu.matchesOverviewSearch("  \n"), "Whitespace-only search shows the normal collection")
        try check(miu.body == secretBody && miu.displayTitle == secretTitle, "Sealed presentation preserves full text for deliberate reading")
        var mine = DiaryEntry(day: "2026-10-09", author: .me, title: "虚构雨天", body: "虚构的散步正文", writingMoment: .later)
        try check(mine.overviewTitle == "虚构雨天" && mine.overviewExcerpt == "虚构的散步正文", "Own previews remain readable")
        try check(mine.matchesOverviewSearch("散步") && mine.matchesOverviewSearch("后来补写"), "Own body and writing labels are searchable")
        try check(DiaryAuthor.me.shortLabel == "小暮暮" && DiaryAuthor.me.rawValue == "me", "Display rename keeps existing stored author identity")
        try check(DiaryAuthor.calendarOrder == [.miu, .me], "Calendar labels put Miu above 小暮暮")
        var otherDay = mine; otherDay.id = UUID(); otherDay.day = "2026-10-08"
        var extraMiu = miu; extraMiu.id = UUID()
        var deleted = miu; deleted.id = UUID(); deleted.day = "2026-10-07"; deleted.deletedAt = Date()
        let groups = DiaryDayGroup.grouped([miu, mine, otherDay, extraMiu, deleted])
        try check(groups.map(\.day) == ["2026-10-09", "2026-10-08"], "Date groups sort recent-first and exclude trash")
        try check(groups[0].miu.count == 2 && groups[0].mine.count == 1, "Counts include all entries on a day, not just two")
        try check(groups.filter(\.hasDifferentCounts).count == 2, "Equal overall totals can still have two mismatched dates")
        try check(!groups[1].matches(author: .miu, query: "", differencesOnly: false), "Author filter excludes dates without that author")
        try check(!groups[0].matches(author: .all, query: secretBody, differencesOnly: false), "Grouped search cannot reveal hidden Miu body")
        try check(groups[0].matches(author: .me, query: "散步", differencesOnly: true), "Author, text and differing-count filters combine")
        let balanced = DiaryDayGroup.grouped([miu, mine])[0]
        try check(!balanced.hasDifferentCounts && !balanced.matches(author: .all, query: "", differencesOnly: true), "Balanced days are excluded only when requested")
        mine.writingMoment = nil
        try check(mine.momentLabel == "未标记" && miu.momentLabel == nil, "Legacy unknown labels are explicit and Miu has no writing category")
    }

    static func writingMomentTests() throws {
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        var entry = DiaryEntry(day: "2026-10-08", author: .me, title: "迁移用虚构标题", body: "迁移用虚构正文\n\n完整保留。", source: .txt, originalFilename: "2026-10-08_test.txt", createdAt: date, updatedAt: date)
        // Emulate actual 1.1.1 bytes, not a new model with a guessed classification.
        var oldEntry = try JSONSerialization.jsonObject(with: DiaryCodec.encode(entry)) as! [String: Any]
        oldEntry.removeValue(forKey: "writingMoment")
        var oldLibrary = try JSONSerialization.jsonObject(with: DiaryCodec.encode(DiaryLibrary())) as! [String: Any]
        oldLibrary["schemaVersion"] = 2; oldLibrary["entries"] = [oldEntry]
        let migrated = try DiaryCodec.decode(DiaryLibrary.self, from: JSONSerialization.data(withJSONObject: oldLibrary))
        try check(migrated.schemaVersion == 3, "Version 2 library migrates to version 3")
        try check(migrated.entries[0] == entry, "Legacy migration preserves IDs, author, dates, title, body, source and timestamps")
        try check(migrated.entries[0].writingMoment == nil, "Import date does not invent an old writing category")
        entry.writingMoment = .onDay
        let marked = try DiaryCodec.decode(DiaryEntry.self, from: DiaryCodec.encode(entry))
        try check(marked.writingMoment == .onDay && marked.body == entry.body, "On-day category survives serialization without changing body")
        let draft = DiaryDraft.editing(marked)
        try check(draft.writingMoment == .onDay && draft.entryID == marked.id, "Editing preserves writing category and original identity")
        var laterDraft = draft; laterDraft.writingMoment = .later
        let restoredDraft = try DiaryCodec.decode(DiaryDraft.self, from: DiaryCodec.encode(laterDraft))
        try check(restoredDraft.writingMoment == .later && restoredDraft.body == marked.body, "Draft autosave retains later-writing selection")
        var lib = DiaryLibrary(); lib.entries = [marked]
        let backup = DiaryBackup(library: lib, drafts: [laterDraft], images: [:])
        let restored = try DiaryRules.decodeBackup(DiaryCodec.encode(backup))
        try check(restored.schemaVersion == 3 && restored.library.entries[0].writingMoment == .onDay && restored.drafts[0].writingMoment == .later, "Full backup preserves both entry and draft labels")
        var oldDraft = try JSONSerialization.jsonObject(with: DiaryCodec.encode(draft)) as! [String: Any]
        oldDraft.removeValue(forKey: "writingMoment")
        var oldBackup = try JSONSerialization.jsonObject(with: DiaryCodec.encode(backup)) as! [String: Any]
        oldBackup["schemaVersion"] = 2; oldBackup["library"] = oldLibrary; oldBackup["drafts"] = [oldDraft]
        let legacy = try DiaryRules.decodeBackup(JSONSerialization.data(withJSONObject: oldBackup))
        try check(legacy.drafts[0].writingMoment == nil && legacy.library.entries[0].body == entry.body, "Old backup restores diaries and unmarked drafts")
        var newer = marked; newer.writingMoment = .later; newer.updatedAt = date.addingTimeInterval(1)
        var incoming = DiaryLibrary(); incoming.entries = [newer]
        let merged = DiaryRules.merging(incoming, into: lib)
        try check(merged.entries[0].writingMoment == .later && merged.entries[0].id == marked.id, "Newer writing label merges without duplicating diary")
        try check(DiaryRules.merging(lib, into: merged).entries[0].writingMoment == .later, "Old backup cannot reset a newer writing label")
        oldEntry["writingMoment"] = "unrecognized-value"
        try rejects("Unrecognized persisted writing category fails rather than silently changing it") { _ = try DiaryCodec.decode(DiaryEntry.self, from: JSONSerialization.data(withJSONObject: oldEntry)) }
    }

    static func navigationTests() throws {
        let october = DayKey.date("2026-10-09")!
        let december = DayKey.date("2026-12-20")!
        var navigation = CalendarNavigation(date: october)
        let initialRequest = navigation.jump.id
        navigation.go(to: october)
        let firstToday = navigation.jump.id
        try check(firstToday != initialRequest, "Today requests centering even in the same month")
        navigation.go(to: october)
        try check(navigation.jump.id != firstToday, "Repeated Today taps always issue a new request")
        navigation.observe(MonthLayout.index(of: december))
        try check(navigation.target(after: firstToday) == MonthLayout.index(of: october), "Intermediate scroll observations cannot redirect a pending Today jump")
        let applied = navigation.jump.id
        try check(navigation.target(after: applied) == MonthLayout.index(of: december), "After a jump is handled, relayout restores the browsed month")
        try check(navigation.jump.id == applied, "Scroll feedback does not create navigation commands")
        navigation.go(to: DayKey.date("2035-04-10")!)
        navigation.go(to: october)
        try check(navigation.target(after: applied) == MonthLayout.index(of: october), "Latest jump wins after a distant date selection")
        try check(navigation.visibleIndex == navigation.jump.monthIndex, "Today initializes the calendar correctly when returning from diary tab")
        navigation.go(to: DayKey.date("2026-11-01")!)
        try check(DayKey.make(navigation.month) == "2026-11-01", "Today uses the newly supplied date after a month boundary")
        navigation.observe(-1)
        try check(navigation.visibleIndex == 0, "Observed month clamps to first supported month")
        navigation.observe(MonthLayout.count)
        try check(navigation.visibleIndex == MonthLayout.count - 1, "Observed month clamps to last supported month")
    }

    static func importTests() throws {
        var handoff = ImportHandoff<String>()
        handoff.begin()
        let fastSession = handoff.session!
        handoff.receive(.success("synthetic fast file"), for: fastSession)
        try check(handoff.takeReadyResult() == nil, "Fast file must wait until picker dismissal before preview")
        handoff.didDismissPicker()
        try check(try handoff.takeReadyResult()?.get() == "synthetic fast file", "Picker dismissal releases a ready preview")
        try check(handoff.takeReadyResult() == nil, "Import preview delivered exactly once")
        handoff.begin()
        let slowSession = handoff.session!
        handoff.didDismissPicker()
        try check(handoff.takeReadyResult() == nil, "Slow provider can finish after the picker closes")
        handoff.receive(.success("synthetic cloud file"), for: slowSession)
        try check(try handoff.takeReadyResult()?.get() == "synthetic cloud file", "Late provider result opens preview after dismissal")
        handoff.begin()
        let cancelledSession = handoff.session!
        handoff.cancel()
        handoff.receive(.success("cancelled"), for: cancelledSession)
        try check(handoff.takeReadyResult() == nil, "Cancel prevents a late callback from opening preview")
        handoff.begin()
        let retrySession = handoff.session!
        handoff.receive(.success("stale"), for: cancelledSession)
        handoff.didDismissPicker()
        try check(handoff.takeReadyResult() == nil, "Previous selection cannot replace a retry")
        handoff.receive(.failure(DiaryFailure.message("synthetic read failure")), for: retrySession)
        let failure = handoff.takeReadyResult()
        try check(failure != nil, "Read error is delivered rather than silently ignored")
        try rejects("Read failure remains actionable") { _ = try failure!.get() }
        handoff.begin(); handoff.didDismissPicker()
        try check(handoff.takeReadyResult() == nil, "Dismissing picker with no file adds nothing")

        try TextImportRules.validateFilename("2026-10-09_Miu.TXT")
        try check(true, "Uppercase Windows TXT extension is accepted")
        try rejects("Renamed extension cannot bypass TXT selection") { try TextImportRules.validateFilename("diary.txt.pdf") }
        try rejects("Extensionless files require an explicit TXT filename") { try TextImportRules.validateFilename("diary") }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("2026-10-09_测试.TXT")
        let text = Data("虚构的导入测试。\r\n\r\n保留空行与猫爪 🐾".utf8)
        try text.write(to: url)
        try check(try BoundedFileReader.read(url, limit: text.count) == text, "Read exact byte limit without truncation")
        let imported = try BoundedFileReader.read(url, limit: 1024)
        try check(try DiaryRules.decodeText(imported) == "虚构的导入测试。\n\n保留空行与猫爪 🐾", "File-to-decoder import retains paragraphs and emoji")
        try rejects("Read refuses files over byte limit") { _ = try BoundedFileReader.read(url, limit: text.count - 1) }
        try rejects("Read refuses a directory") { _ = try BoundedFileReader.read(directory, limit: 1024) }
        try rejects("Missing file produces a read error") { _ = try BoundedFileReader.read(directory.appendingPathComponent("missing.txt"), limit: 1024) }
        try Data().write(to: url)
        try rejects("Empty imported file fails text validation") { _ = try DiaryRules.decodeText(BoundedFileReader.read(url, limit: 1024)) }
        let manyChunks = Data(repeating: 65, count: 140_000)
        try manyChunks.write(to: url)
        try check(try BoundedFileReader.read(url, limit: manyChunks.count) == manyChunks, "Chunked reads retain the complete file")
    }
}
