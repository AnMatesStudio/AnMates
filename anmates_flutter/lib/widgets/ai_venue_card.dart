import 'package:flutter/material.dart';
import '../models/ai_venue_card.dart';
import '../services/concierge_service.dart';
import '../services/maps_launcher.dart';
import '../theme/app_theme.dart';
import 'anm_logo.dart';

/// Renders an `ai_venue_card` chat message: the AI Concierge's top-3 venue
/// suggestion. Venue facts come from the backend AI venue-search service
/// (MCP web-search). [onSuggest] fires when the user taps "Gợi ý cho Mate".
///
/// When [onReanchor] is provided (live mode) the card shows anchor chips so the
/// user can re-center the search at the midpoint, near themselves, or near their
/// mate (e.g. "A picks up B → eat near B"). Re-anchoring updates the card in
/// place for the requester only; it is not posted back to the chat.
class AiVenueCard extends StatefulWidget {
  final AiVenueCardContent content;
  final ValueChanged<AiVenuePick>? onSuggest;
  final String? mateName;
  final Future<AiVenueCardContent?> Function(VenueAnchor anchor)? onReanchor;

  const AiVenueCard({
    super.key,
    required this.content,
    this.onSuggest,
    this.mateName,
    this.onReanchor,
  });

  @override
  State<AiVenueCard> createState() => _AiVenueCardState();
}

class _AiVenueCardState extends State<AiVenueCard> {
  late AiVenueCardContent _content;
  VenueAnchor _anchor = VenueAnchor.midpoint;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _content = widget.content;
  }

  Future<void> _select(VenueAnchor anchor) async {
    if (_loading || anchor == _anchor || widget.onReanchor == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final next = await widget.onReanchor!(anchor);
      if (!mounted) return;
      if (next != null && next.picks.isNotEmpty) {
        setState(() {
          _content = next;
          _anchor = anchor;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = 'Không tìm được quán phù hợp ở khu vực này.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được gợi ý, thử lại nhé.';
      });
    }
  }

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
            _content.intro,
            style: AppTextStyles.body(size: 14, color: AppColors.ink),
          ),
          if (widget.onReanchor != null) ...[
            const SizedBox(height: 10),
            _AnchorChips(
              selected: _anchor,
              mateName: widget.mateName,
              loading: _loading,
              onSelect: _select,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTextStyles.body(size: 12, color: AppColors.berry),
            ),
          ],
          const SizedBox(height: 10),
          ...List.generate(_content.picks.length, (i) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: i == _content.picks.length - 1 ? 0 : 10),
              child: _PickRow(
                rank: i + 1,
                pick: _content.picks[i],
                onSuggest: widget.onSuggest,
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// The "Điểm giữa / Gần mình / Gần <mate>" anchor selector.
class _AnchorChips extends StatelessWidget {
  final VenueAnchor selected;
  final String? mateName;
  final bool loading;
  final ValueChanged<VenueAnchor> onSelect;

  const _AnchorChips({
    required this.selected,
    required this.mateName,
    required this.loading,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final mate = (mateName == null || mateName!.trim().isEmpty)
        ? 'Mate'
        : mateName!.trim();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _chip('Điểm giữa', VenueAnchor.midpoint),
        _chip('Gần mình', VenueAnchor.me),
        _chip('Gần $mate', VenueAnchor.mate),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(left: 2),
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.berry,
              ),
            ),
          ),
      ],
    );
  }

  Widget _chip(String label, VenueAnchor anchor) {
    final isSel = anchor == selected;
    return GestureDetector(
      onTap: loading ? null : () => onSelect(anchor),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? AppColors.berry : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSel ? AppColors.berry : AppColors.ink10,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.body(
            size: 12,
            weight: FontWeight.w700,
            color: isSel ? Colors.white : AppColors.ink70,
          ),
        ),
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
                    // Tapping the name opens the venue in Google Maps (new tab
                    // on web, Maps app on mobile w/ web fallback).
                    GestureDetector(
                      onTap: () => MapsLauncher.open(
                        name: pick.name,
                        address: pick.address,
                        lat: pick.lat,
                        lng: pick.lng,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Text(
                              pick.name,
                              style: AppTextStyles.display(
                                size: 14,
                                weight: FontWeight.w700,
                                color: AppColors.berry,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.map_outlined,
                              size: 14,
                              color: AppColors.berry,
                            ),
                          ),
                        ],
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
