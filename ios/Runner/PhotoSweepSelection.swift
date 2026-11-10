import Foundation

/// One sweep is a range applied to a snapshot. Reversing restores earlier choices.
struct PhotoSweepSelection {
  let limit: Int
  private(set) var selected = Set<Int>()
  private var baseline = Set<Int>()
  private var anchor: Int?
  private var adding = true
  mutating func toggle(_ index: Int) {
    guard index >= 0 else { return }
    if selected.contains(index) { selected.remove(index) }
    else if selected.count < limit { selected.insert(index) }
  }
  mutating func begin(at index: Int) {
    baseline = selected; anchor = index; adding = !selected.contains(index)
    move(to: index)
  }
  mutating func move(to index: Int) {
    guard let start = anchor, index >= 0 else { return }
    selected = baseline
    let step = index >= start ? 1 : -1
    for item in stride(from: start, through: index, by: step) {
      if adding {
        if selected.count >= limit { break }; selected.insert(item)
      } else { selected.remove(item) }
    }
  }
  mutating func end() { anchor = nil; baseline.removeAll() }
  mutating func reset() { selected.removeAll(); end() }
}
