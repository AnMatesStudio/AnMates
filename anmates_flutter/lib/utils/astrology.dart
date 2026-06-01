/// Pure-Dart astrology + numerology helpers for the onboarding auto-detect
/// section (Screen 08). No Flutter dependencies — easy to unit test.
library;

/// Western zodiac sign for a date of birth.
class ZodiacSign {
  final String vi; // Vietnamese name, e.g. "Song Tử"
  final String en; // English name, e.g. "Gemini"
  final String range; // human range, e.g. "21/5 – 21/6"
  const ZodiacSign(this.vi, this.en, this.range);
}

/// Returns the Western zodiac sign for [dob].
ZodiacSign zodiacSign(DateTime dob) {
  final m = dob.month;
  final d = dob.day;
  // Each entry: (startMonth, startDay, vi, en, range). Capricorn wraps the year.
  if ((m == 3 && d >= 21) || (m == 4 && d <= 19)) {
    return const ZodiacSign('Bạch Dương', 'Aries', '21/3 – 19/4');
  }
  if ((m == 4 && d >= 20) || (m == 5 && d <= 20)) {
    return const ZodiacSign('Kim Ngưu', 'Taurus', '20/4 – 20/5');
  }
  if ((m == 5 && d >= 21) || (m == 6 && d <= 21)) {
    return const ZodiacSign('Song Tử', 'Gemini', '21/5 – 21/6');
  }
  if ((m == 6 && d >= 22) || (m == 7 && d <= 22)) {
    return const ZodiacSign('Cự Giải', 'Cancer', '22/6 – 22/7');
  }
  if ((m == 7 && d >= 23) || (m == 8 && d <= 22)) {
    return const ZodiacSign('Sư Tử', 'Leo', '23/7 – 22/8');
  }
  if ((m == 8 && d >= 23) || (m == 9 && d <= 22)) {
    return const ZodiacSign('Xử Nữ', 'Virgo', '23/8 – 22/9');
  }
  if ((m == 9 && d >= 23) || (m == 10 && d <= 23)) {
    return const ZodiacSign('Thiên Bình', 'Libra', '23/9 – 23/10');
  }
  if ((m == 10 && d >= 24) || (m == 11 && d <= 21)) {
    return const ZodiacSign('Bọ Cạp', 'Scorpio', '24/10 – 21/11');
  }
  if ((m == 11 && d >= 22) || (m == 12 && d <= 21)) {
    return const ZodiacSign('Nhân Mã', 'Sagittarius', '22/11 – 21/12');
  }
  if ((m == 12 && d >= 22) || (m == 1 && d <= 19)) {
    return const ZodiacSign('Ma Kết', 'Capricorn', '22/12 – 19/1');
  }
  if ((m == 1 && d >= 20) || (m == 2 && d <= 18)) {
    return const ZodiacSign('Bảo Bình', 'Aquarius', '20/1 – 18/2');
  }
  return const ZodiacSign('Song Ngư', 'Pisces', '19/2 – 20/3');
}

// ── Sexagenary (Can Chi) cycle ───────────────────────────────────────────────

const _heavenlyStems = [
  'Giáp', 'Ất', 'Bính', 'Đinh', 'Mậu', 'Kỷ', 'Canh', 'Tân', 'Nhâm', 'Quý',
];

const _earthlyBranches = [
  'Tý', 'Sửu', 'Dần', 'Mão', 'Thìn', 'Tị',
  'Ngọ', 'Mùi', 'Thân', 'Dậu', 'Tuất', 'Hợi',
];

/// Heavenly stem (Thiên Can) for a lunar-ish calendar year, e.g. 2001 → "Tân".
String heavenlyStem(int year) => _heavenlyStems[((year - 4) % 10 + 10) % 10];

/// Earthly branch (Địa Chi) for a year, e.g. 2001 → "Tị".
String earthlyBranch(int year) =>
    _earthlyBranches[((year - 4) % 12 + 12) % 12];

/// Full Can Chi label for a year, e.g. 2001 → "Tân Tị".
String canChi(int year) => '${heavenlyStem(year)} ${earthlyBranch(year)}';

// ── Nạp Âm (30-element table, each covers 2 sexagenary positions) ─────────────

const _napAm = <String>[
  'Hải Trung Kim', // Giáp Tý, Ất Sửu
  'Lư Trung Hỏa', // Bính Dần, Đinh Mão
  'Đại Lâm Mộc', // Mậu Thìn, Kỷ Tị
  'Lộ Bàng Thổ', // Canh Ngọ, Tân Mùi
  'Kiếm Phong Kim', // Nhâm Thân, Quý Dậu
  'Sơn Đầu Hỏa', // Giáp Tuất, Ất Hợi
  'Giản Hạ Thủy', // Bính Tý, Đinh Sửu
  'Thành Đầu Thổ', // Mậu Dần, Kỷ Mão
  'Bạch Lạp Kim', // Canh Thìn, Tân Tị
  'Dương Liễu Mộc', // Nhâm Ngọ, Quý Mùi
  'Tuyền Trung Thủy', // Giáp Thân, Ất Dậu
  'Ốc Thượng Thổ', // Bính Tuất, Đinh Hợi
  'Tích Lịch Hỏa', // Mậu Tý, Kỷ Sửu
  'Tùng Bách Mộc', // Canh Dần, Tân Mão
  'Trường Lưu Thủy', // Nhâm Thìn, Quý Tị
  'Sa Trung Kim', // Giáp Ngọ, Ất Mùi
  'Sơn Hạ Hỏa', // Bính Thân, Đinh Dậu
  'Bình Địa Mộc', // Mậu Tuất, Kỷ Hợi
  'Bích Thượng Thổ', // Canh Tý, Tân Sửu
  'Kim Bạch Kim', // Nhâm Dần, Quý Mão
  'Phú Đăng Hỏa', // Giáp Thìn, Ất Tị
  'Thiên Hà Thủy', // Bính Ngọ, Đinh Mùi
  'Đại Trạch Thổ', // Mậu Thân, Kỷ Dậu
  'Thoa Xuyến Kim', // Canh Tuất, Tân Hợi
  'Tang Đố Mộc', // Nhâm Tý, Quý Sửu
  'Đại Khê Thủy', // Giáp Dần, Ất Mão
  'Sa Trung Thổ', // Bính Thìn, Đinh Tị
  'Thiên Thượng Hỏa', // Mậu Ngọ, Kỷ Mùi
  'Thạch Lựu Mộc', // Canh Thân, Tân Dậu
  'Đại Hải Thủy', // Nhâm Tuất, Quý Hợi
];

/// Nạp Âm (ngũ hành nạp âm) name for a year, e.g. 2001 → "Bạch Lạp Kim".
String napAm(int year) {
  final sexagenary = ((year - 4) % 60 + 60) % 60;
  return _napAm[sexagenary ~/ 2];
}

/// The element (Kim/Mộc/Thủy/Hỏa/Thổ) embedded in the Nạp Âm name.
String napAmElement(int year) {
  final name = napAm(year);
  for (final e in const ['Kim', 'Mộc', 'Thủy', 'Hỏa', 'Thổ']) {
    if (name.endsWith(e)) return e;
  }
  return '';
}

// ── Numerology (life path) ───────────────────────────────────────────────────

int _sumDigits(int n) {
  var s = 0;
  for (final ch in n.toString().split('')) {
    s += int.parse(ch);
  }
  return s;
}

/// Life-path number for a date of birth. Reduces to a single digit, preserving
/// master numbers 11, 22, 33. e.g. 24/05/2001 → 5.
int lifePathNumber(DateTime dob) {
  var total = _sumDigits(dob.day) + _sumDigits(dob.month) + _sumDigits(dob.year);
  while (total > 9 && total != 11 && total != 22 && total != 33) {
    total = _sumDigits(total);
  }
  return total;
}

const _lifePathLabels = <int, String>{
  1: 'Độc lập · Tiên phong',
  2: 'Hợp tác · Nhạy cảm',
  3: 'Sáng tạo · Biểu đạt',
  4: 'Kỷ luật · Nền tảng',
  5: 'Tự do · Phiêu lưu',
  6: 'Trách nhiệm · Yêu thương',
  7: 'Trí tuệ · Nội tâm',
  8: 'Quyền lực · Thành đạt',
  9: 'Nhân ái · Lý tưởng',
  11: 'Trực giác · Truyền cảm hứng',
  22: 'Kiến tạo · Tầm nhìn lớn',
  33: 'Dẫn dắt · Chữa lành',
};

/// Human-friendly label for a life-path number.
String lifePathLabel(int n) => _lifePathLabels[n] ?? '';
