import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

class DiningGroupSheet extends StatefulWidget {
  final Place place;
  const DiningGroupSheet({super.key, required this.place});

  @override
  State<DiningGroupSheet> createState() => _DiningGroupSheetState();
}

class _DiningGroupSheetState extends State<DiningGroupSheet> {
  final _nameCtrl = TextEditingController();
  int _maxMembers = 4;
  Mood _selectedMood = Mood.hungry;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
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
            Row(
              children: [
                const Icon(Icons.group, color: AppColors.berry, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Tạo nhóm đi ${widget.place.emoji}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2D42),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Tên nhóm...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Số thành viên tối đa',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                const Spacer(),
                Row(
                  children: [2, 3, 4].map((n) {
                    final isSelected = _maxMembers == n;
                    return GestureDetector(
                      onTap: () => setState(() => _maxMembers = n),
                      child: Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.berry
                              : const Color(0xFF2D2D42),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$n',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Mood hôm nay',
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
              children: Mood.values
                  .map(
                    (m) => GestureDetector(
                      onTap: () => setState(() => _selectedMood = m),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedMood == m
                              ? m.color.withValues(alpha: 0.3)
                              : const Color(0xFF2D2D42),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _selectedMood == m
                                ? m.color
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(m.emoji),
                            const SizedBox(width: 4),
                            Text(
                              m.label,
                              style: TextStyle(
                                color: _selectedMood == m
                                    ? m.color
                                    : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.berry, AppColors.wisteria],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text(
                    'Tạo nhóm',
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
