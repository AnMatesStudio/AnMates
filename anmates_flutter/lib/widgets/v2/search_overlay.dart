import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_theme_v2.dart';
import '../../views/v2/v2_data.dart';

/// Blur-and-keyboard search layer (canvas frame B1.3).
///
/// The design mocks an iOS keyboard inside the frame; on device we let the real
/// keyboard come up and autofocus the field instead.
class SearchOverlay extends StatefulWidget {
  const SearchOverlay({
    super.key,
    required this.onClose,
    required this.onOpenVenue,
    required this.en,
  });

  final VoidCallback onClose;
  final ValueChanged<Venue> onOpenVenue;
  final bool en;

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Design rule: below three characters everything matches, so the list reads as
  /// a browsable shortlist rather than an empty state while you type.
  List<Venue> get _results {
    final q = _controller.text.toLowerCase();
    return kVenues
        .where((v) => q.length < 3 || '${v.name} ${v.area}'.toLowerCase().contains(q))
        .take(4)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: ColoredBox(color: AppColorsV2.canvas.withValues(alpha: 0.55)),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 46, 18, 0),
                child: Row(
                  children: [
                    Expanded(child: _field(hasText)),
                    GestureDetector(
                      onTap: widget.onClose,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          widget.en ? 'Cancel' : 'Huỷ',
                          style: AppTextV2.name(color: AppColorsV2.wisteria, size: 13.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: hasText ? _resultList() : _recentChips(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(bool hasText) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColorsV2.wisteria.withValues(alpha: 0.35), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A285A).withValues(alpha: 0.14),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 18, color: AppColorsV2.wisteria),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: true,
              cursorColor: AppColorsV2.wisteria,
              style: AppTextV2.body(color: AppColorsV2.ink, size: 14)
                  .copyWith(fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: widget.en
                    ? 'Search a spot, a dish, a district'
                    : 'Tìm quán, món, khu vực',
                hintStyle: AppTextV2.body(color: AppColorsV2.inkA(0.45), size: 14),
              ),
            ),
          ),
          if (hasText)
            GestureDetector(
              onTap: _controller.clear,
              child: Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColorsV2.inkA(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, size: 12, color: AppColorsV2.ink),
              ),
            ),
        ],
      ),
    );
  }

  Widget _recentChips() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.en ? 'RECENT' : 'GẦN ĐÂY', style: AppTextV2.eyebrow()),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in kRecentSearches)
                GestureDetector(
                  onTap: () {
                    _controller.text = q;
                    _controller.selection =
                        TextSelection.collapsed(offset: q.length);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColorsV2.inkA(0.07)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0A285A).withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(q, style: AppTextV2.name(size: 12.5)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultList() {
    final results = _results;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      itemCount: results.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(widget.en ? 'RESULTS' : 'KẾT QUẢ', style: AppTextV2.eyebrow()),
          );
        }
        final v = results[i - 1];
        return GestureDetector(
          onTap: () => widget.onOpenVenue(v),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColorsV2.inkA(0.06)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0A285A).withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F7FD),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Image.asset(v.img, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.name, style: AppTextV2.name(size: 13.5)),
                      const SizedBox(height: 2),
                      Text(
                        '${v.area} · ${v.dist} · ${v.price}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextV2.meta().copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Text(
                  '★ ${v.rating}',
                  style: AppTextV2.name(color: AppColorsV2.wisteria, size: 11),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
