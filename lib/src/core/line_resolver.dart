// by claude
part of lrc;

/// Finds the line playing at a position: the last one starting at or before it.
///
/// The previous result is kept, so playback moving forward resolves in constant time and other jumps binary search.
class LrcLineResolver {
  /// a seek to a line start can land a few ms before it.
  static const kToleranceMS = 5;

  static final empty = LrcLineResolver(Int32List(0), Int32List(0));

  /// ascending line starts in milliseconds.
  final Int32List startsMS;

  /// the line index each of [startsMS] resolves to.
  final Int32List lineIndices;

  int _slot = -1;

  LrcLineResolver(this.startsMS, this.lineIndices);

  int get length => startsMS.length;

  /// the index in [startsMS] of the line playing at [positionMS], -1 before the first line.
  int slotAt(int positionMS) {
    final targetMS = positionMS + kToleranceMS;
    final starts = startsMS;
    final length = starts.length;
    var slot = _slot;
    if (slot >= 0 && starts[slot] > targetMS) {
      slot = upperBound(targetMS) - 1;
    } else {
      final nextSlot = slot + 1;
      if (nextSlot < length && starts[nextSlot] <= targetMS) {
        final afterNextSlot = nextSlot + 1;
        final didSkipLines = afterNextSlot < length && starts[afterNextSlot] <= targetMS;
        slot = didSkipLines ? upperBound(targetMS) - 1 : nextSlot;
      }
    }
    _slot = slot;
    return slot;
  }

  /// the index of the line playing at [positionMS], -1 before the first line.
  int indexAt(int positionMS) {
    final slot = slotAt(positionMS);
    return slot < 0 ? -1 : lineIndices[slot];
  }

  /// how many of [startsMS] are at or before [positionMS].
  int upperBound(int positionMS) {
    final starts = startsMS;
    var low = 0;
    var high = starts.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (starts[mid] <= positionMS) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }
}
