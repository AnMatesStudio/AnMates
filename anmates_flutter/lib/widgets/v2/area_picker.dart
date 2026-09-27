import 'package:flutter/material.dart';

import '../../theme/app_theme_v2.dart';
import '../../views/v2/v2_kit.dart';

/// District chips for the venue and mates filters: a search box, then the
/// first [collapsedCount] names (picked ones always show) and a "+ Thêm" chip
/// that lists the rest. The search ignores case and Vietnamese diacritics.
class AreaPicker extends StatefulWidget {
  const AreaPicker({
    super.key,
    required this.names,
    required this.selected,
    required this.onToggle,
    required this.en,
    this.collapsedCount = 6,
  });

  final List<String> names;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final bool en;
  final int collapsedCount;

  @override
  State<AreaPicker> createState() => _AreaPickerState();
}

class _AreaPickerState extends State<AreaPicker> {
  final TextEditingController _controller = TextEditingController();
  bool _expanded = false;
  String _query = '';

  String _t(String vi, String en) => widget.en ? en : vi;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final names = widget.names;
    final n = widget.collapsedCount;

    final q = foldVietnamese(_query.trim());
    final List<int> shown;
    if (q.isNotEmpty) {
      shown = [for (var i = 0; i < names.length; i++) if (foldVietnamese(names[i]).contains(q)) i];
    } else if (_expanded) {
      shown = [for (var i = 0; i < names.length; i++) i];
    } else {
      shown = [
        for (var i = 0; i < names.length; i++)
          if (i < n || widget.selected.contains(names[i])) i,
      ];
    }

    final hidden = names.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 42,
          child: TextField(
            key: const Key('area-search'),
            controller: _controller,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            style: AppTextV2.body(size: 13.5),
            decoration: InputDecoration(
              isDense: true,
              hintText: _t('Tìm khu vực…', 'Search areas…'),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 18,
                color: AppColorsV2.inkA(0.42),
              ),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, size: 16),
                      tooltip: _t('Xoá', 'Clear'),
                      onPressed: () => setState(() {
                        _controller.clear();
                        _query = '';
                      }),
                    )
                  : null,
              filled: true,
              fillColor: AppColorsV2.inkA(0.04),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_query.isNotEmpty && shown.isEmpty)
          Text(
            _t('Không tìm thấy khu vực "$_query"', 'No area matches "$_query"'),
            style: AppTextV2.body(color: AppColorsV2.inkA(0.5), size: 12.5),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final i in shown)
                V2Chip(
                  label: names[i],
                  selected: widget.selected.contains(names[i]),
                  onTap: () => widget.onToggle(names[i]),
                ),
              if (_query.isEmpty && names.length > n)
                if (_expanded)
                  V2Chip(
                    key: const Key('area-less'),
                    label: _t('Thu gọn', 'Show less'),
                    selected: false,
                    onTap: () => setState(() => _expanded = false),
                  )
                else
                  V2Chip(
                    key: const Key('area-more'),
                    label: _t('+ Thêm ($hidden)', '+ More ($hidden)'),
                    selected: false,
                    onTap: () => setState(() => _expanded = true),
                  ),
            ],
          ),
      ],
    );
  }
}

/// Lower-cases and strips Vietnamese diacritics so "quan 1" finds "Quận 1" and
/// "thu duc" finds "Thủ Đức". `đ` has no Unicode decomposition — map it explicitly.
String foldVietnamese(String s) {
  const groups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ', 'e': 'èéẹẻẽêềếệểễ', 'i': 'ìíịỉĩ', 'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ', 'y': 'ỳýỵỷỹ', 'd': 'đ',
  };
  final out = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    var mapped = ch;
    for (final e in groups.entries) {
      if (e.value.contains(ch)) {
        mapped = e.key;
        break;
      }
    }
    out.write(mapped);
  }
  return out.toString();
}
