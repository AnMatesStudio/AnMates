import 'package:flutter/material.dart';

import '../../services/extras_service.dart';
import '../../theme/app_theme_v2.dart';
import '../../views/v2/v2_data.dart';
import '../../views/v2/v2_kit.dart';
import '../../views/v2/v2_state.dart';

/// Opens the Me screen's "Sửa hồ sơ" sheet.
Future<void> showEditProfileSheet(BuildContext context, V2State s) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditProfileSheet(s: s),
    );

/// The Me screen's edit-profile sheet: name, bio, up to three vibe chips and
/// a spend tier. Everything starts from what [s] already holds (null prefs
/// mean an empty form), and "Lưu" runs [V2State.saveProfile].
class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({super.key, required this.s});

  final V2State s;

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController _nameC = TextEditingController(text: widget.s.profileName);
  late final TextEditingController _bioC = TextEditingController(text: widget.s.profileBio);
  late final Set<int> _vibes = _initialVibes();
  late int? _tier = widget.s.prefs?.priceTier;
  bool _saving = false;

  /// Saved vibe codes back to kVibeTags indexes; unknown codes are dropped so
  /// a newer build's chips never light up out of range.
  Set<int> _initialVibes() {
    final codes = widget.s.prefs?.vibeTags;
    if (codes == null) return <int>{};
    final out = <int>{};
    for (final code in codes) {
      final i = kVibeCodes.indexOf(code);
      if (i >= 0) out.add(i);
    }
    return out;
  }

  @override
  void dispose() {
    _nameC.dispose();
    _bioC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    // Captured before the await: by the time saveProfile returns the sheet
    // (and its context) may already be gone.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final clearance = navClearance(context);
    setState(() => _saving = true);
    final ok = await widget.s.saveProfile(
      name: _nameC.text,
      bio: _bioC.text,
      vibes: _vibes,
      priceTier: _tier,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    final s = widget.s;
    if (ok) {
      Navigator.of(context).pop();
      showV2Toast(messenger, s.t('Đã lưu hồ sơ', 'Profile saved'), bottom: clearance);
    } else {
      showV2Toast(
          messenger,
          s.t('Không lưu được — tên không được trống', 'Could not save — name is required'),
          bottom: clearance);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    // Keyboard inset pushed into the bottom padding: the sheet grows with the
    // keyboard instead of ending up behind it.
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.t('Sửa hồ sơ', 'Edit profile'),
              style: AppTextV2.section().copyWith(fontSize: 22),
            ),
            _label(s.t('Tên hiển thị', 'Display name')),
            TextField(
              key: const Key('edit-name'),
              controller: _nameC,
              maxLength: 40,
              decoration: _fieldDecoration(widget.s.t('Tên hiển thị', 'Display name')),
            ),
            _label(s.t('Giới thiệu', 'About you')),
            TextField(
              key: const Key('edit-bio'),
              controller: _bioC,
              maxLength: 200,
              maxLines: 3,
              decoration: _fieldDecoration(widget.s.t('Giới thiệu', 'About you')),
            ),
            _label(s.t('Vibe của bạn (tối đa 3)', 'Your vibe (up to 3)')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < kVibeTags.length; i++)
                  V2Chip(
                    label: s.tr(kVibeTags[i]),
                    selected: _vibes.contains(i),
                    onTap: () => setState(() {
                      if (_vibes.contains(i)) {
                        _vibes.remove(i);
                      } else if (_vibes.length < 3) {
                        // A 4th tap does nothing: the label promises max 3.
                        _vibes.add(i);
                      }
                    }),
                  ),
              ],
            ),
            _label(s.t('Chi tiêu mỗi bữa', 'Spend per meal')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                V2Chip(
                  label: s.t('Không chọn', 'No preference'),
                  selected: _tier == null,
                  onTap: () => setState(() => _tier = null),
                ),
                for (var i = 0; i < kPrices.length; i++)
                  V2Chip(
                    label: kPrices[i],
                    selected: _tier == i,
                    onTap: () => setState(() => _tier = i),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            V2Cta(
              key: const Key('edit-save'),
              label: _saving ? s.t('Đang lưu…', 'Saving…') : s.t('Lưu', 'Save'),
              onTap: _save,
            ),
          ],
        ),
      ),
    );
  }

  /// A 13pt bold label with 14 pt above and 6 pt below.
  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(text, style: AppTextV2.name(size: 13)),
      );

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColorsV2.inkA(0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColorsV2.inkA(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColorsV2.wisteria, width: 1.5),
        ),
        helperStyle: AppTextV2.meta(),
      );
}
