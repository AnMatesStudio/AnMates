import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../../../theme/v2_layout.dart';
import '../legal_texts.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **Terms of Use / Privacy Policy** — the two legal documents in
/// [legal_texts.dart], rendered from their numbered sections in the active
/// language. The same screen serves both; [privacy] picks the document, the
/// title and the back destination (Me when signed in, the sign-in screen
/// otherwise).
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.privacy});

  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();

    return SingleChildScrollView(
      key: Key(privacy ? 'legal-privacy' : 'legal-terms'),
      padding: EdgeInsets.fromLTRB(
        V2Layout.hPad(context), V2Layout.contentTop(context),
        V2Layout.hPad(context), navClearance(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: V2BackButton(
                onTap: () => s.go(s.signedIn ? V2Screen.me : V2Screen.auth)),
          ),
          const SizedBox(height: 16),
          Text(_legalTitle(privacy, s),
              style: AppTextV2.section().copyWith(fontSize: 25)),
          const SizedBox(height: 4),
          Text(_legalMeta(s), style: AppTextV2.meta()),
          const SizedBox(height: 18),
          LegalBody(s: s, privacy: privacy),
        ],
      ),
    );
  }
}

/// The numbered sections (headings + paragraphs) of the Terms or Privacy
/// document in the active language — shared by [LegalScreen] and the legal
/// sheet so both stay identical.
class LegalBody extends StatelessWidget {
  const LegalBody({super.key, required this.s, required this.privacy});

  final V2State s;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final sections = privacy ? kPrivacy : kTerms;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 18),
          Text('${i + 1}. ${s.en ? sections[i].titleEn : sections[i].titleVi}',
              style: AppTextV2.name(size: 15)),
          const SizedBox(height: 8),
          for (final p in (s.en ? sections[i].en : sections[i].vi)) ...[
            Text(p, style: AppTextV2.body(size: 13.5).copyWith(height: 1.5)),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

/// Shows the Terms / Privacy Policy over the current screen (a modal sheet), so a
/// half-filled form underneath keeps its state.
Future<void> showLegalSheet(BuildContext context, V2State s,
        {required bool privacy}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
          heightFactor: 0.9,
          child: _LegalSheet(s: s, privacy: privacy)),
    );

/// White bottom sheet with a drag-handle bar, the document title and a close
/// button, the meta line, then the scrollable [LegalBody].
class _LegalSheet extends StatelessWidget {
  const _LegalSheet({required this.s, required this.privacy});

  final V2State s;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key(privacy ? 'legal-sheet-privacy' : 'legal-sheet-terms'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 5,
              decoration: BoxDecoration(
                color: AppColorsV2.inkA(0.16),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(_legalTitle(privacy, s),
                    style: AppTextV2.section().copyWith(fontSize: 22)),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: s.t('Đóng', 'Close'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Text(_legalMeta(s), style: AppTextV2.meta()),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: LegalBody(s: s, privacy: privacy),
            ),
          ),
        ],
      ),
    );
  }
}

/// The document title in the active language, for [LegalScreen] and the sheet.
String _legalTitle(bool privacy, V2State s) => privacy
    ? s.t('Chính sách quyền riêng tư', 'Privacy Policy')
    : s.t('Điều khoản sử dụng', 'Terms of Use');

/// The "Updated …" meta line, shared by [LegalScreen] and the sheet.
String _legalMeta(V2State s) => s.t('Cập nhật $kLegalUpdated', 'Updated $kLegalUpdated');
