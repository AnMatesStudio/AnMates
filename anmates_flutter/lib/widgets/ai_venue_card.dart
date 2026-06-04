import 'package:flutter/material.dart';
import '../models/ai_venue_card.dart';
import '../theme/app_theme.dart';
import 'anm_logo.dart';

/// Renders an `ai_venue_card` chat message: the AI Concierge's top-3 venue
/// suggestion. Venue facts come from the backend (DB-sourced, never invented).
/// [onSuggest] fires when the user taps "Gợi ý cho Mate" on a pick.
class AiVenueCard extends StatelessWidget {
  final AiVenueCardContent content;
  final ValueChanged<AiVenuePick>? onSuggest;

  const AiVenueCard({super.key, required this.content, this.onSuggest});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.berry.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.berry.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Sparkle(size: 16, color: AppColors.berry),
              const SizedBox(width: 6),
              Text(
                'TRỢ LÝ ĂNMATES',
                style: AppTextStyles.mono(
                  size: 10,
                  weight: FontWeight.w700,
                  color: AppColors.berry,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content.intro,
            style: AppTextStyles.body(size: 14, color: AppColors.ink),
          ),
          const SizedBox(height: 10),
          ...List.generate(content.picks.length, (i) {
            return Padding(
              padding: EdgeInsets.only(bottom: i == content.picks.length - 1 ? 0 : 10),
              child: _PickRow(
                rank: i + 1,
                pick: content.picks[i],
                onSuggest: onSuggest,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  final int rank;
  final AiVenuePick pick;
  final ValueChanged<AiVenuePick>? onSuggest;

  const _PickRow({required this.rank, required this.pick, this.onSuggest});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ink10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.berry,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$rank',
                  style: AppTextStyles.mono(
                    size: 11,
                    weight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pick.name,
                      style: AppTextStyles.display(
                        size: 14,
                        weight: FontWeight.w700,
                        color: AppColors.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _metaLine(pick),
                      style: AppTextStyles.body(size: 11, color: AppColors.ink50),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (pick.reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '“${pick.reason}”',
              style: AppTextStyles.body(size: 12, color: AppColors.ink70),
            ),
          ],
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onSuggest == null ? null : () => onSuggest!(pick),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.berry,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Gợi ý cho Mate →',
                style: AppTextStyles.body(
                  size: 13,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _metaLine(AiVenuePick p) {
    final parts = <String>[];
    if (p.rating != null) parts.add('★ ${p.rating!.toStringAsFixed(1)}');
    if (p.distanceLabel.isNotEmpty) parts.add(p.distanceLabel);
    if (p.priceLabel.isNotEmpty) parts.add('${p.priceLabel}đ');
    return parts.join(' · ');
  }
}
