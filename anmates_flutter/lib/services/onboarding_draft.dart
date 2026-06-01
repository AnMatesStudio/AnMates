import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DraftPhoto {
  final Uint8List bytes;
  String? caption;
  String? uploadedUrl;
  DraftPhoto({required this.bytes, this.caption, this.uploadedUrl});
}

class OnboardingDraftController extends ChangeNotifier {
  OnboardingDraftController._();
  static final OnboardingDraftController instance = OnboardingDraftController._();

  static const _prefsKey = 'onboarding_draft';

  // Screen 09 bounds
  static const minFood = 2;
  static const maxFood = 5;
  // Screen 10 bounds (each section: culture + vibe)
  static const minVibe = 2;
  static const maxVibe = 5;

  static const minAge = 16;
  static const maxExtraPhotos = 2;

  // ── Screen 08 ──────────────────────────────────────────────────────────────
  String name = '';
  String nickname = '';
  int day = 15;
  int month = 6;
  int year = 2000;
  bool dobTouched = false;
  double personality = 50;

  // ── Screen 09 (Gú Ẩm Thực) ────────────────────────────────────────────────
  final Set<String> food = {};

  // ── Screen 10 (Thích Vibe Nào) ─────────────────────────────────────────────
  final Set<String> culture = {}; // Nền văn minh yêu thích
  final Set<String> vibe    = {}; // Vibe buổi ăn

  // ── Screen 11 (Show bản thân) ──────────────────────────────────────────────
  DraftPhoto? mainPhoto;
  final List<DraftPhoto> extraPhotos = [];

  // ── Validation errors ──────────────────────────────────────────────────────
  String? nameError;
  String? nicknameError;
  String? dobError;
  String? foodError;
  String? cultureError;
  String? vibeError;
  String? photoError;

  DateTime get dob => DateTime(year, month, day);

  int get ageYears {
    final now = DateTime.now();
    var age = now.year - year;
    if (now.month < month || (now.month == month && now.day < day)) age--;
    return age;
  }

  int get photoCount => (mainPhoto != null ? 1 : 0) + extraPhotos.length;

  Future<void> reset() async {
    name = '';
    nickname = '';
    day = 15;
    month = 6;
    year = 2000;
    dobTouched = false;
    personality = 50;
    food.clear();
    culture.clear();
    vibe.clear();
    mainPhoto = null;
    extraPhotos.clear();
    clearErrors();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    notifyListeners();
  }

  void clearErrors() {
    nameError = null;
    nicknameError = null;
    dobError = null;
    foodError = null;
    cultureError = null;
    vibeError = null;
    photoError = null;
  }

  static final _lettersOnly = RegExp(r"^[\p{L} ]+$", unicode: true);

  String? _validateNameValue(String value, String fieldName) {
    final v = value.trim();
    if (v.isEmpty) return 'Bạn chưa nhập $fieldName';
    if (!_lettersOnly.hasMatch(v)) {
      return '$fieldName chỉ được chứa chữ, không chứa số hay ký tự đặc biệt';
    }
    return null;
  }

  bool validateStep08({bool notify = true}) {
    nameError = _validateNameValue(name, 'Tên đầy đủ');
    nicknameError = _validateNameValue(nickname, 'tên gọi thân mật');
    if (!dobTouched) {
      dobError = 'Bạn chưa chọn ngày tháng năm sinh';
    } else if (ageYears < minAge) {
      dobError = 'Bạn chưa đủ $minAge tuổi để dùng ĂnMates';
    } else {
      dobError = null;
    }
    if (notify) notifyListeners();
    return nameError == null && nicknameError == null && dobError == null;
  }

  /// Screen 09 — Gú Ẩm Thực (2–5 food tags).
  bool validateStep09({bool notify = true}) {
    if (food.length < minFood) {
      foodError = 'Chọn tối thiểu $minFood thẻ (đang ${food.length})';
    } else if (food.length > maxFood) {
      foodError = 'Chọn tối đa $maxFood thẻ';
    } else {
      foodError = null;
    }
    if (notify) notifyListeners();
    return foodError == null;
  }

  /// Screen 10 — Thích Vibe Nào (each section: 2–5 tags).
  bool validateVibeScreen({bool notify = true}) {
    if (culture.isEmpty) {
      cultureError = 'Bạn chưa chọn nền văn minh yêu thích';
    } else {
      cultureError = null;
    }
    if (vibe.length < minVibe) {
      vibeError = 'Chọn tối thiểu $minVibe vibe buổi ăn (đang ${vibe.length})';
    } else if (vibe.length > maxVibe) {
      vibeError = 'Chọn tối đa $maxVibe vibe buổi ăn';
    } else {
      vibeError = null;
    }
    if (notify) notifyListeners();
    return cultureError == null && vibeError == null;
  }

  /// Screen 11 — photo (main photo required).
  bool validateStep10({bool notify = true}) {
    photoError = mainPhoto == null ? 'Bạn chưa chọn Ảnh chính' : null;
    if (notify) notifyListeners();
    return photoError == null;
  }

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    final map = {
      'name': name,
      'nickname': nickname,
      'day': day,
      'month': month,
      'year': year,
      'dobTouched': dobTouched,
      'personality': personality,
      'food': food.toList(),
      'culture': culture.toList(),
      'vibe': vibe.toList(),
    };
    await prefs.setString(_prefsKey, jsonEncode(map));
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      name      = map['name']      as String? ?? '';
      nickname  = map['nickname']  as String? ?? '';
      day       = map['day']       as int?    ?? day;
      month     = map['month']     as int?    ?? month;
      year      = map['year']      as int?    ?? year;
      dobTouched= map['dobTouched']as bool?   ?? false;
      personality=(map['personality'] as num?)?.toDouble() ?? 50;
      food
        ..clear()
        ..addAll((map['food']    as List?)?.cast<String>() ?? const []);
      culture
        ..clear()
        ..addAll((map['culture'] as List?)?.cast<String>() ?? const []);
      vibe
        ..clear()
        ..addAll((map['vibe']    as List?)?.cast<String>() ?? const []);
    } catch (_) {}
  }
}
