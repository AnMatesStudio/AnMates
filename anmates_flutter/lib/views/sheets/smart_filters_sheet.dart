import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

class SmartFiltersSheet extends StatefulWidget {
  final PlaceFilter filter;
  final ValueChanged<PlaceFilter> onApply;
  const SmartFiltersSheet({
    super.key,
    required this.filter,
    required this.onApply,
  });

  @override
  State<SmartFiltersSheet> createState() => _SmartFiltersSheetState();
}

class _SmartFiltersSheetState extends State<SmartFiltersSheet> {
  late PlaceFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = PlaceFilter(
      distance: widget.filter.distance,
      maxPrice: widget.filter.maxPrice,
      minRating: widget.filter.minRating,
      openNow: widget.filter.openNow,
      suitableFor: widget.filter.suitableFor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bộ lọc thông minh',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _SliderRow(
              label: 'Khoảng cách',
              value: _filter.distance,
              min: 0.5,
              max: 20,
              unit: 'km',
              onChanged: (v) => setState(() => _filter.distance = v),
            ),
            _SliderRow(
              label: 'Giá tối đa',
              value: _filter.maxPrice,
              min: 50,
              max: 2000,
              unit: 'k',
              onChanged: (v) => setState(() => _filter.maxPrice = v),
            ),
            _SliderRow(
              label: 'Rating tối thiểu',
              value: _filter.minRating,
              min: 1,
              max: 5,
              unit: '★',
              onChanged: (v) => setState(() => _filter.minRating = v),
            ),
            Row(
              children: [
                const Text(
                  'Đang mở cửa',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                const Spacer(),
                Switch(
                  value: _filter.openNow,
                  activeThumbColor: AppColors.berry,
                  onChanged: (v) => setState(() => _filter.openNow = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Phù hợp với',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PlaceFilter.suitableOptions
                  .map(
                    (o) => GestureDetector(
                      onTap: () => setState(() => _filter.suitableFor = o),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _filter.suitableFor == o
                              ? AppColors.berry.withValues(alpha: 0.3)
                              : const Color(0xFF2D2D42),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _filter.suitableFor == o
                                ? AppColors.berry
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          o,
                          style: TextStyle(
                            color: _filter.suitableFor == o
                                ? AppColors.wisteria
                                : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                widget.onApply(_filter);
                Navigator.pop(context);
              },
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.berry,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text(
                    'Áp dụng',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const Spacer(),
            Text(
              '${value.toStringAsFixed(unit == 'km' ? 1 : 0)}$unit',
              style: const TextStyle(
                color: AppColors.wisteria,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.berry,
            inactiveTrackColor: const Color(0xFF2D2D42),
            thumbColor: AppColors.berry,
            overlayColor: AppColors.berry.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
