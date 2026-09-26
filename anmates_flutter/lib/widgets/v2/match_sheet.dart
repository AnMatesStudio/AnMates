import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_theme_v2.dart';
import '../../views/v2/v2_data.dart';
import '../../views/v2/v2_kit.dart';
import '../../views/v2/v2_mate_mapper.dart';

/// "Hợp gu rồi!" — shown after an invite the other person had already
/// returned. For a real match, "Nhắn tin chốt kèo" opens the chat; a sample
/// profile says plainly that no conversation exists behind it.
class MatchSheet extends StatelessWidget {
  const MatchSheet({
    super.key,
    required this.en,
    required this.partner,
    required this.sample,
    required this.onChat,
    required this.onClose,
  });

  final bool en;
  final Mate partner;
  final bool sample;
  final VoidCallback onChat;
  final VoidCallback onClose;

  String _t(String vi, String enText) => en ? enText : vi;

  @override
  Widget build(BuildContext context) {
    final foods = partner.overlapFoods.take(3).map(tasteLabel).join(', ');

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: ColoredBox(color: const Color(0xFF181430).withValues(alpha: 0.55)),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sample
                              ? _t('HỒ SƠ MẪU', 'SAMPLE PROFILE')
                              : _t('${partner.name.toUpperCase()} ĐÃ MỜI LẠI',
                                  '${partner.name.toUpperCase()} INVITED YOU BACK'),
                          textAlign: TextAlign.center,
                          style: AppTextV2.eyebrow(color: AppColorsV2.wisteria),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _t('Hợp gu rồi!', "It's a match!"),
                          style: AppTextV2.section().copyWith(fontSize: 28, letterSpacing: -0.8),
                        ),
                        const SizedBox(height: 14),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 74, height: 74,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColorsV2.ink,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: Text(_t('Bạn', 'You'),
                                style: AppTextV2.name(color: Colors.white, size: 18)),
                          ),
                          Transform.translate(
                            offset: const Offset(-14, 0),
                            child: MateAvatar(
                              name: partner.name,
                              userId: partner.userId,
                              url: partner.avatarUrl,
                              size: 74,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        Text(
                          foods.isEmpty
                              ? _t('Bạn và ${partner.name} đã mời nhau đi ăn.',
                                  'You and ${partner.name} invited each other.')
                              : _t('Bạn và ${partner.name} cùng thích $foods.',
                                  'You and ${partner.name} both like $foods.'),
                          textAlign: TextAlign.center,
                          style: AppTextV2.body(color: AppColorsV2.inkA(0.65), size: 14),
                        ),
                        if (sample) ...[
                          const SizedBox(height: 8),
                          Text(
                            _t('Đây là hồ sơ mẫu nên không có cuộc trò chuyện thật.',
                                "This is a sample profile, so there's no real chat."),
                            textAlign: TextAlign.center,
                            style: AppTextV2.meta(color: AppColorsV2.inkA(0.5)),
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (!sample) ...[
                          SizedBox(
                            width: double.infinity,
                            child: V2Cta(
                              label: _t('Nhắn tin chốt kèo', 'Message to set it up'),
                              height: 52,
                              fontSize: 15,
                              onTap: onChat,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: sample
                              ? V2Cta(label: _t('Quẹt tiếp', 'Keep swiping'), height: 52, fontSize: 15, onTap: onClose)
                              : GestureDetector(
                                  onTap: onClose,
                                  child: Container(
                                    height: 50,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppColorsV2.wisteriaTint,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(_t('Quẹt tiếp', 'Keep swiping'),
                                        style: AppTextV2.name(color: const Color(0xFF6D28D9), size: 14.5)),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
