import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

class ReviewCheckinSheet extends StatefulWidget {
  final Place place;
  const ReviewCheckinSheet({super.key, required this.place});

  @override
  State<ReviewCheckinSheet> createState() => _ReviewCheckinSheetState();
}

class _ReviewCheckinSheetState extends State<ReviewCheckinSheet> {
  int _rating = 5;
  final _reviewCtrl = TextEditingController();
  final List<String> _allTags = [
    'Romantic 💕',
    'Instagrammable 📸',
    'Lively 🎉',
    'Quiet 🤫',
    'Foodie 🍜',
    'Chill ☕',
    'Music 🎵',
  ];
  final Set<String> _selectedTags = {};

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
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
            Text(
              'Check-in ${widget.place.emoji} ${widget.place.name}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Kiếm +30 AnPoints',
              style: TextStyle(color: Color(0xFFfdcb6e), fontSize: 12),
            ),
            const SizedBox(height: 20),
            // Rating
            const Text(
              'Đánh giá của bạn',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => GestureDetector(
                  onTap: () => setState(() => _rating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      i < _rating ? Icons.star : Icons.star_border,
                      color: Colors.yellow,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Vibe tags
            const Text(
              'Vibe ở đây',
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
              children: _allTags
                  .map(
                    (t) => GestureDetector(
                      onTap: () => setState(() {
                        if (_selectedTags.contains(t)) {
                          _selectedTags.remove(t);
                        } else {
                          _selectedTags.add(t);
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedTags.contains(t)
                              ? AppColors.berry.withValues(alpha: 0.3)
                              : const Color(0xFF2D2D42),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _selectedTags.contains(t)
                                ? AppColors.berry
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            color: _selectedTags.contains(t)
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
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2D42),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _reviewCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Chia sẻ trải nghiệm của bạn...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFfdcb6e), Color(0xFFe17055)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text(
                    'Gửi đánh giá & Check-in',
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
