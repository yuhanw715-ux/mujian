import Foundation

enum DiaryAuthor: String, Codable, CaseIterable, Identifiable {
    case me, miu
    var id: String { rawValue }
    var label: String { self == .me ? "我写的" : "Miu写的" }
    var shortLabel: String { self == .me ? "我" : "Miu" }
}

enum DiarySource: String, Codable { case typed, txt }

struct DiaryEntry: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var day: String
    var author: DiaryAuthor
    var title: String
    var body: String
    var source: DiarySource = .typed
    var originalFilename: String? = nil
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deletedAt: Date? = nil
    var displayTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? author.label : title }
    var excerpt: String { body.prefix(600).split(whereSeparator: { $0.isNewline }).prefix(4).joined(separator: " ") }
}

struct DiaryDraft: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var entryID: UUID? = nil
    var day: String
    var author: DiaryAuthor = .me
    var title: String = ""
    var body: String = ""
    var source: DiarySource = .typed
    var originalFilename: String? = nil
    var updatedAt: Date = Date()
    var hasContent: Bool { !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    static func editing(_ entry: DiaryEntry) -> DiaryDraft {
        DiaryDraft(entryID: entry.id, day: entry.day, author: entry.author, title: entry.title,
                   body: entry.body, source: entry.source, originalFilename: entry.originalFilename)
    }
}

struct BackgroundStyle: Codable, Equatable {
    var imageName: String? = nil
    var showsImage: Bool = true
    var veil: Double = 0.38
    var blur: Double = 0
}

struct DiaryLibrary: Codable, Equatable {
    var schemaVersion: Int = 2
    var entries: [DiaryEntry] = []
    var defaultBackground: BackgroundStyle = BackgroundStyle()
    var dayBackgrounds: [String: BackgroundStyle] = [:]
    var readerFontSize: Double = 18
    var appearance = CalendarAppearance()

    init() {}
    enum CodingKeys: String, CodingKey {
        case schemaVersion, entries, defaultBackground, dayBackgrounds, readerFontSize, appearance
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let version = try values.decode(Int.self, forKey: .schemaVersion)
        guard (1...2).contains(version) else { throw DiaryFailure.message("这个日记文件需要其他版本的暮笺。") }
        schemaVersion = 2
        entries = try values.decode([DiaryEntry].self, forKey: .entries)
        defaultBackground = try values.decode(BackgroundStyle.self, forKey: .defaultBackground)
        dayBackgrounds = try values.decode([String: BackgroundStyle].self, forKey: .dayBackgrounds)
        readerFontSize = try values.decode(Double.self, forKey: .readerFontSize)
        appearance = try values.decodeIfPresent(CalendarAppearance.self, forKey: .appearance) ?? CalendarAppearance()
    }
    var activeEntries: [DiaryEntry] { entries.filter { $0.deletedAt == nil } }
    func entries(on day: String) -> [DiaryEntry] {
        activeEntries.filter { $0.day == day }.sorted {
            if $0.author != $1.author { return $0.author == .me }
            return $0.createdAt < $1.createdAt
        }
    }
    var referencedImages: Set<String> {
        Set(([defaultBackground] + Array(dayBackgrounds.values)).compactMap(\.imageName)).union(appearance.referencedImages)
    }
}

struct DiaryBackup: Codable {
    var documentType: String = "app.miu.mujian.backup"
    var schemaVersion: Int = 2
    var exportedAt: Date = Date()
    var library: DiaryLibrary
    var drafts: [DiaryDraft]
    var images: [String: Data]
}

enum DiaryFailure: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let message): return message }
    }
}

enum DiaryCodec {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(type, from: data)
    }
}
