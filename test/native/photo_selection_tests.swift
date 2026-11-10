import Foundation
@main struct PhotoSelectionTests {
  static func main() {
    var s = PhotoSweepSelection(limit: 5)
    s.begin(at: 2); s.move(to: 5)
    assert(s.selected == Set(2...5))
    s.move(to: 3); assert(s.selected == Set(2...3), "backtracking restores baseline")
    s.end(); s.toggle(8)
    s.begin(at: 3); s.move(to: 2)
    assert(s.selected == [8], "dragging a selected anchor deselects the range")
    s.end(); s.begin(at: 6); s.move(to: 1)
    assert(s.selected.count == 5 && s.selected.contains(8) && s.selected.contains(6))
    assert(s.selected == [8,6,5,4,3], "fill cap in gesture direction, retain preexisting")
    s.move(to: 5); assert(s.selected == [8,6,5])
    s.end(); s.toggle(5); assert(s.selected == [8,6])
    s.begin(at: 2); s.move(to: 4); s.end()
    assert(s.selected == [2,3,4,6,8])
    s.toggle(9); assert(s.selected.count == 5)
    s.reset(); assert(s.selected.isEmpty)
    var big = PhotoSweepSelection(limit: 500)
    big.begin(at: 0); big.move(to: 1000); assert(big.selected.count == 500)
    big.move(to: 1); assert(big.selected == [0,1])
    big.end(); big.begin(at: 1); big.move(to: 0); assert(big.selected.isEmpty)
    print("PhotoSweepSelection: forward, reverse, shrink, deselect, baseline and 500 cap passed")
  }
}
