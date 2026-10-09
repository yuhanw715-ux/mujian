import Foundation

struct ImportFile: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let data: Data
}

/// File providers can finish before or after the picker disappears. Deliver once,
/// only after dismissal, and ignore callbacks from a cancelled/previous selection.
struct ImportHandoff<Value> {
    private(set) var session: UUID?
    private var pickerDismissed = true
    private var pending: Result<Value, Error>?
    mutating func begin() {
        session = UUID(); pending = nil; pickerDismissed = false
    }
    mutating func receive(_ result: Result<Value, Error>, for id: UUID) {
        guard session == id else { return }
        pending = result
    }
    mutating func didDismissPicker() { pickerDismissed = true }
    mutating func takeReadyResult() -> Result<Value, Error>? {
        guard pickerDismissed, let result = pending else { return nil }
        cancel()
        return result
    }
    mutating func cancel() { session = nil; pending = nil; pickerDismissed = true }
}

enum TextImportRules {
    static func validateFilename(_ name: String) throws {
        guard (name as NSString).pathExtension.lowercased() == "txt" else {
            throw DiaryFailure.message("请选一个 .txt 文件，Miu 会把它完整收藏成一篇。")
        }
    }
}

enum BoundedFileReader {
    static func read(_ url: URL, limit: Int) throws -> Data {
        guard limit > 0 else { throw DiaryFailure.message("文件大小限制不正确。") }
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true else { throw DiaryFailure.message("请选择文件，而不是文件夹。") }
        guard (values.fileSize ?? 0) <= limit else { throw tooLarge }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        // Bound actual reads as well as reported size; a provider's metadata may be stale.
        while let chunk = try handle.read(upToCount: min(64 * 1024, limit - data.count + 1)), !chunk.isEmpty {
            guard chunk.count <= limit - data.count else { throw tooLarge }
            data.append(chunk)
        }
        return data
    }
    private static var tooLarge: DiaryFailure { .message("这个文件太大了，请选择较小的文件。") }
}
