import SwiftUI
import UIKit
import ImageIO

struct LocalSnapshot: Codable {
    var library = DiaryLibrary()
    var drafts: [DiaryDraft] = []
}

@MainActor
final class DiaryStore: ObservableObject {
    @Published private(set) var state = LocalSnapshot()
    @Published private(set) var loadIssue: String?
    @Published var message: String?
    let root: URL
    private let imageCache = NSCache<NSString, UIImage>()
    var library: DiaryLibrary { state.library }
    var drafts: [DiaryDraft] { state.drafts.sorted { $0.updatedAt > $1.updatedAt } }
    var isReadOnly: Bool { loadIssue != nil }
    private var stateURL: URL { root.appendingPathComponent("library.json") }
    private var imageFolder: URL { root.appendingPathComponent("Images", isDirectory: true) }

    init() {
        root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mujian", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: imageFolder, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: stateURL.path) {
                let loaded = try DiaryCodec.decode(LocalSnapshot.self, from: Data(contentsOf: stateURL))
                try DiaryRules.validateLibrary(loaded.library)
                try Self.validateDrafts(loaded.drafts)
                state = loaded
            }
        } catch {
            loadIssue = "暂时无法读取本地日记，原文件已保留。请在设置中导出原文件，或恢复暮笺备份。\n\(error.localizedDescription)"
        }
    }

    private static func validateDrafts(_ drafts: [DiaryDraft]) throws {
        guard Set(drafts.map(\.id)).count == drafts.count else { throw DiaryFailure.message("草稿编号重复。") }
        for draft in drafts {
            guard DayKey.date(draft.day) != nil, draft.title.count <= 200,
                  draft.body.utf8.count <= DiaryRules.maxTextBytes else { throw DiaryFailure.message("草稿格式不正确。") }
        }
    }

    private func commit(_ candidate: LocalSnapshot, recovering: Bool = false) throws {
        guard !isReadOnly || recovering else { throw DiaryFailure.message(loadIssue ?? "本地文件暂时只读。") }
        try DiaryRules.validateLibrary(candidate.library)
        try Self.validateDrafts(candidate.drafts)
        let bytes = try DiaryCodec.encode(candidate)
        if let old = try? Data(contentsOf: stateURL) {
            if recovering && isReadOnly {
                let rescued = root.appendingPathComponent("preserved-\(UUID().uuidString).json")
                try old.write(to: rescued, options: [.atomic, .completeFileProtection])
            } else {
                try old.write(to: root.appendingPathComponent("previous.json"), options: [.atomic, .completeFileProtection])
            }
        }
        try bytes.write(to: stateURL, options: [.atomic, .completeFileProtection])
        state = candidate
        if recovering { loadIssue = nil }
    }

    func entry(_ id: UUID) -> DiaryEntry? { library.activeEntries.first { $0.id == id } }
    func draft(for entry: DiaryEntry) -> DiaryDraft {
        drafts.first { $0.entryID == entry.id } ?? .editing(entry)
    }
    func saveDraft(_ draft: DiaryDraft) throws {
        var next = state
        next.drafts.removeAll { $0.id == draft.id }
        if draft.hasContent { next.drafts.append(draft) }
        try commit(next)
    }
    func discardDraft(_ id: UUID) throws {
        var next = state
        next.drafts.removeAll { $0.id == id }
        try commit(next)
    }
    @discardableResult
    func save(_ draft: DiaryDraft) throws -> UUID {
        var next = state
        let existing = draft.entryID.flatMap { id in next.library.entries.first { $0.id == id } }
        guard existing?.deletedAt == nil else { throw DiaryFailure.message("原日记在回收站中，请先恢复它。") }
        var entry = DiaryEntry(day: draft.day, author: draft.author, title: draft.title, body: draft.body,
                               source: draft.source, originalFilename: draft.originalFilename)
        if let existing { entry.id = existing.id; entry.createdAt = existing.createdAt }
        entry.updatedAt = Date()
        try DiaryRules.validateEntry(entry)
        next.library.entries.removeAll { $0.id == entry.id }
        next.library.entries.append(entry)
        next.drafts.removeAll { $0.id == draft.id || $0.entryID == entry.id }
        try commit(next)
        return entry.id
    }
    func setDeleted(_ id: UUID, deleted: Bool) throws {
        var next = state
        guard let index = next.library.entries.firstIndex(where: { $0.id == id }) else { return }
        next.library.entries[index].deletedAt = deleted ? Date() : nil
        next.library.entries[index].updatedAt = Date()
        try commit(next)
    }
    func permanentlyDelete(_ id: UUID) throws {
        var next = state
        next.library.entries.removeAll { $0.id == id }
        next.drafts.removeAll { $0.entryID == id }
        try commit(next)
    }

    func style(for day: String?) -> BackgroundStyle {
        day.flatMap { library.dayBackgrounds[$0] } ?? library.defaultBackground
    }
    func setStyle(_ style: BackgroundStyle, for day: String?) throws {
        var next = state
        if let day { next.library.dayBackgrounds[day] = style }
        else { next.library.defaultBackground = style }
        try commit(next)
    }
    func resetDayStyle(_ day: String) throws {
        var next = state
        next.library.dayBackgrounds.removeValue(forKey: day)
        try commit(next)
    }
    func setFontSize(_ size: Double) throws {
        var next = state
        next.library.readerFontSize = size
        try commit(next)
    }
    func setAppearance(_ appearance: CalendarAppearance) throws {
        var next = state
        next.library.appearance = appearance
        try commit(next)
    }
    func image(named name: String) -> UIImage? {
        guard DiaryRules.safeImageName(name) else { return nil }
        if let cached = imageCache.object(forKey: name as NSString) { return cached }
        guard let image = UIImage(contentsOfFile: imageFolder.appendingPathComponent(name).path) else { return nil }
        imageCache.setObject(image, forKey: name as NSString)
        return image
    }
    func storeImage(_ data: Data, preservingAlpha: Bool = false) throws -> String {
        guard data.count <= 40 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: preservingAlpha ? 1200 : 1800
              ] as CFDictionary) else {
            throw DiaryFailure.message("这张图片暂时读不了，请选择一张小于 40 MB 的照片。")
        }
        let image = UIImage(cgImage: thumb)
        guard let bytes = preservingAlpha ? image.pngData() : image.jpegData(compressionQuality: 0.85),
              bytes.count <= 12 * 1024 * 1024 else { throw DiaryFailure.message("这张图片太大，请换一张较小的图片。") }
        let name = UUID().uuidString + (preservingAlpha ? ".png" : ".jpg")
        try bytes.write(to: imageFolder.appendingPathComponent(name), options: [.atomic, .completeFileProtection])
        return name
    }

    func backupData() throws -> Data {
        guard !isReadOnly else { throw DiaryFailure.message("请先导出原文件，或恢复备份。") }
        var images: [String: Data] = [:]
        for name in library.referencedImages {
            images[name] = try Data(contentsOf: imageFolder.appendingPathComponent(name))
        }
        let backup = DiaryBackup(library: library, drafts: drafts, images: images)
        let data = try DiaryCodec.encode(backup)
        guard data.count <= DiaryRules.maxBackupBytes else { throw DiaryFailure.message("完整备份超过 150 MB，请减少自定义背景后重试。日记仍保存在本机。") }
        return data
    }
    func originalData() throws -> Data { try Data(contentsOf: stateURL) }

    func restore(_ backup: DiaryBackup) throws {
        // All data has already been validated in the restore preview. Validate again at the write boundary.
        _ = try DiaryRules.decodeBackup(DiaryCodec.encode(backup))
        var incoming = backup.library
        for (name, bytes) in backup.images {
            guard UIImage(data: bytes) != nil else { throw DiaryFailure.message("备份中的背景图片已损坏。") }
            var destination = name
            let file = imageFolder.appendingPathComponent(name)
            if let old = try? Data(contentsOf: file), old != bytes {
                destination = UUID().uuidString + ".jpg"
                if name.hasSuffix(".png") { destination = UUID().uuidString + ".png" }
                incoming.appearance.remapImage(name, to: destination)
                if incoming.defaultBackground.imageName == name { incoming.defaultBackground.imageName = destination }
                for day in Array(incoming.dayBackgrounds.keys) where incoming.dayBackgrounds[day]?.imageName == name {
                    incoming.dayBackgrounds[day]?.imageName = destination
                }
            }
            try bytes.write(to: imageFolder.appendingPathComponent(destination), options: [.atomic, .completeFileProtection])
        }
        let isEmpty = library.entries.isEmpty && drafts.isEmpty
        var next = state
        next.library = (isReadOnly || isEmpty) ? incoming : DiaryRules.merging(incoming, into: library)
        var allDrafts = Dictionary(uniqueKeysWithValues: next.drafts.map { ($0.id, $0) })
        for draft in backup.drafts {
            if let current = allDrafts[draft.id], current.updatedAt >= draft.updatedAt { continue }
            allDrafts[draft.id] = draft
        }
        next.drafts = Array(allDrafts.values)
        try commit(next, recovering: true)
        imageCache.removeAllObjects()
    }
    func attempt(_ action: () throws -> Void) {
        do { try action() } catch { message = error.localizedDescription }
    }
}
