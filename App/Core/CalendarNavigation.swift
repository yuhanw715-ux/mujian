import Foundation

/// Observed scroll position is separate from an explicit request to center a month.
/// Repeated taps on Today must produce a request even when its month is already visible.
struct CalendarNavigation: Equatable {
    struct Jump: Equatable {
        let id: UUID
        let monthIndex: Int
    }
    private(set) var visibleIndex: Int
    private(set) var jump: Jump
    var month: Date { MonthLayout.date(at: visibleIndex) }

    init(date: Date = Date()) {
        let index = MonthLayout.index(of: date)
        visibleIndex = index
        jump = Jump(id: UUID(), monthIndex: index)
    }
    mutating func go(to date: Date) {
        let index = MonthLayout.index(of: date)
        visibleIndex = index
        jump = Jump(id: UUID(), monthIndex: index)
    }
    mutating func observe(_ index: Int) {
        visibleIndex = min(MonthLayout.count - 1, max(0, index))
    }
    func target(after handledRequest: UUID) -> Int {
        handledRequest == jump.id ? visibleIndex : jump.monthIndex
    }
}
