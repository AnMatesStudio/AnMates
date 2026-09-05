/// Pragmatic parser for the OSM `opening_hours` string so the UI can show a
/// live "Đang mở cửa" / "Đã đóng" badge instead of dumping the raw spec at the
/// user. (Feature A — ported from the google-maps-scraper "hours" concept, but
/// fed by the venue data in our DB — no external source.)
///
/// The full OSM grammar is huge; this handles the cases that actually appear on
/// Vietnamese food venues:
///   - `24/7`
///   - `Mo-Su 08:00-22:00`
///   - `Mo-Fr 09:00-21:00; Sa-Su 10:00-22:00`   (multiple rules, `;`-separated)
///   - `Mo-We,Fr 09:00-17:00`                    (day lists with `,`)
///   - `10:00-14:00,17:00-22:00`                 (split shifts)
///   - `18:00-02:00`                             (ranges that cross midnight)
///   - bare `08:00-22:00`                        (applies every day)
///   - `Mo off` / `Su closed`                    (explicit closed days)
/// Anything it can't confidently parse degrades to [OpenNow.unknown] with the
/// raw string preserved, so callers can fall back to showing it verbatim.
library;

enum OpenNow { open, closed, unknown }

class OpeningStatus {
  final OpenNow state;

  /// Full label, e.g. "Đang mở · đóng 22:00" or "Đã đóng · mở 08:00".
  final String label;

  /// Compact label for tight rows, e.g. "Đang mở" / "Đã đóng" / the raw hours.
  final String shortLabel;

  const OpeningStatus(this.state, this.label, this.shortLabel);

  bool get isOpen => state == OpenNow.open;
  bool get isClosed => state == OpenNow.closed;
  bool get isKnown => state != OpenNow.unknown;
}

const _unknown = OpeningStatus(OpenNow.unknown, '', '');

/// A single applicable time window in minutes-from-midnight. [end] <= [start]
/// means the window wraps past midnight (e.g. 18:00–02:00).
class _Window {
  final Set<int> days; // 1=Mon … 7=Sun
  final int start;
  final int end;
  const _Window(this.days, this.start, this.end);

  bool get wraps => end <= start;
}

/// Parses [raw] and decides whether the venue is open at [now] (defaults to the
/// current local time).
OpeningStatus parseOpeningHours(String? raw, {DateTime? now}) {
  final src = raw?.trim();
  if (src == null || src.isEmpty) return _unknown;

  final clock = now ?? DateTime.now();
  final today = clock.weekday; // 1..7
  final yesterday = today == 1 ? 7 : today - 1;
  final nowMin = clock.hour * 60 + clock.minute;

  if (src.replaceAll(' ', '').contains('24/7')) {
    return const OpeningStatus(OpenNow.open, 'Mở cả ngày', 'Mở 24/7');
  }

  final windows = <_Window>[];
  for (final rule in src.split(';')) {
    windows.addAll(_parseRule(rule));
  }
  if (windows.isEmpty) return _unknown;

  // 1) Already open — find the window covering `now`, prefer the one that tells
  //    us when it closes.
  int? closeAt;
  for (final w in windows) {
    final coversToday = w.days.contains(today) &&
        (w.wraps ? (nowMin >= w.start || nowMin < w.end)
                 : (nowMin >= w.start && nowMin < w.end));
    // A window opened yesterday can still be running after midnight today.
    final coversFromYesterday =
        w.wraps && w.days.contains(yesterday) && nowMin < w.end;
    if (coversToday || coversFromYesterday) {
      closeAt = w.end;
      break;
    }
  }
  if (closeAt != null) {
    return OpeningStatus(
      OpenNow.open,
      'Đang mở · đóng ${_fmt(closeAt)}',
      'Đang mở',
    );
  }

  // 2) Closed now — find the next opening time later today, if any.
  int? nextOpen;
  for (final w in windows) {
    if (w.days.contains(today) && w.start > nowMin) {
      nextOpen = nextOpen == null ? w.start : (w.start < nextOpen ? w.start : nextOpen);
    }
  }
  if (nextOpen != null) {
    return OpeningStatus(
      OpenNow.closed,
      'Đã đóng · mở ${_fmt(nextOpen)}',
      'Đã đóng',
    );
  }
  return const OpeningStatus(OpenNow.closed, 'Đã đóng', 'Đã đóng');
}

/// Parses one `;`-delimited rule into zero or more windows. Returns empty for
/// "off"/"closed" rules or anything unrecognized.
List<_Window> _parseRule(String rule) {
  final r = rule.trim();
  if (r.isEmpty) return const [];

  final lower = r.toLowerCase();
  // Split the day prefix (if any) from the time spec. A leading time token
  // (starts with a digit) means the rule applies every day.
  final firstSpace = r.indexOf(' ');
  String dayPart;
  String timePart;
  if (RegExp(r'^\d').hasMatch(r) || firstSpace < 0) {
    dayPart = '';
    timePart = r;
  } else {
    dayPart = r.substring(0, firstSpace).trim();
    timePart = r.substring(firstSpace + 1).trim();
  }

  if (lower.endsWith('off') || lower.endsWith('closed')) return const [];

  final days = dayPart.isEmpty ? {1, 2, 3, 4, 5, 6, 7} : _parseDays(dayPart);
  if (days.isEmpty) return const [];

  final out = <_Window>[];
  for (final span in timePart.split(',')) {
    final m = RegExp(r'(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})').firstMatch(span.trim());
    if (m == null) continue;
    final start = int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
    final end = int.parse(m.group(3)!) * 60 + int.parse(m.group(4)!);
    out.add(_Window(days, start, end));
  }
  return out;
}

const _dayOrder = ['mo', 'tu', 'we', 'th', 'fr', 'sa', 'su'];

/// Parses a day spec like "Mo-Fr", "Sa,Su", "Mo-We,Fr" into a set of 1..7.
Set<int> _parseDays(String spec) {
  final out = <int>{};
  for (final token in spec.split(',')) {
    final t = token.trim().toLowerCase();
    if (t.contains('-')) {
      final ends = t.split('-');
      final a = _dayOrder.indexOf(ends[0].trim().substring(0, _min2(ends[0].trim())));
      final b = _dayOrder.indexOf(ends[1].trim().substring(0, _min2(ends[1].trim())));
      if (a < 0 || b < 0) continue;
      // Inclusive range, wrapping through the week if needed (e.g. Sa-Mo).
      var i = a;
      while (true) {
        out.add(i + 1);
        if (i == b) break;
        i = (i + 1) % 7;
      }
    } else {
      if (t.length < 2) continue;
      final i = _dayOrder.indexOf(t.substring(0, 2));
      if (i >= 0) out.add(i + 1);
    }
  }
  return out;
}

int _min2(String s) => s.length < 2 ? s.length : 2;

String _fmt(int minutes) {
  final h = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}
