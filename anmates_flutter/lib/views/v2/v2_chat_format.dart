/// Messenger-style time labels for the inbox and the chat transcript.
library;

String _two(int n) => n.toString().padLeft(2, '0');

String _weekday(DateTime t, bool en) {
  const vi = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  const enNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return (en ? enNames : vi)[t.weekday - 1];
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// The inbox row's time: "19:30" today, "T6" this week, "12/09" before that.
String inboxTime(DateTime at, {required bool en, DateTime? now}) {
  final t = at.toLocal();
  final n = now ?? DateTime.now();
  if (_sameDay(t, n)) return '${_two(t.hour)}:${_two(t.minute)}';
  final days = DateTime(n.year, n.month, n.day).difference(DateTime(t.year, t.month, t.day)).inDays;
  if (days > 0 && days < 7) return _weekday(t, en);
  return '${_two(t.day)}/${_two(t.month)}';
}

/// The centred separator in the transcript: "19:30", "T6 19:30", "12/09 19:30".
String separatorTime(DateTime at, {required bool en, DateTime? now}) {
  final t = at.toLocal();
  final n = now ?? DateTime.now();
  final hm = '${_two(t.hour)}:${_two(t.minute)}';
  if (_sameDay(t, n)) return hm;
  final days = DateTime(n.year, n.month, n.day).difference(DateTime(t.year, t.month, t.day)).inDays;
  if (days > 0 && days < 7) return '${_weekday(t, en)} $hm';
  return '${_two(t.day)}/${_two(t.month)} $hm';
}

/// A gap this long between two messages starts a new time separator.
const Duration kSeparatorGap = Duration(minutes: 15);

/// Messages closer than this from the same sender stack as one group.
const Duration kGroupGap = Duration(minutes: 3);

/// Only emoji (up to a few), which Messenger draws large without a bubble.
bool isBigEmoji(String text) {
  final t = text.trim();
  if (t.isEmpty) return false;
  var count = 0;
  for (final r in t.runes) {
    if (r == 0xFE0F || r == 0x200D || (r >= 0x1F3FB && r <= 0x1F3FF)) continue; // joiners, skin tones
    final emoji = r >= 0x1F000 || (r >= 0x2600 && r <= 0x27BF) || (r >= 0x2B00 && r <= 0x2BFF);
    if (!emoji) return false;
    count++;
  }
  return count <= 3;
}
