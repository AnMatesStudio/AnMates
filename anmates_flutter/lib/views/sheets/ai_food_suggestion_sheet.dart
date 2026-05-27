import 'package:flutter/material.dart';
import '../../models/models.dart';

class AIFoodSuggestionSheet extends StatefulWidget {
  final Place place;
  const AIFoodSuggestionSheet({super.key, required this.place});

  @override
  State<AIFoodSuggestionSheet> createState() => _AIFoodSuggestionSheetState();
}

class _AIFoodSuggestionSheetState extends State<AIFoodSuggestionSheet> {
  int _groupSize = 2;
  Mood _mood = Mood.hungry;

  List<FoodSuggestion> get _suggestions =>
      FoodSuggestion.suggestions(_groupSize, _mood);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
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
                const Text('🤖', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Gợi Ý Món',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Dựa trên nhóm, mood & ngân sách',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text(
                  'Số người',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                const Spacer(),
                Row(
                  children: [2, 3, 4].map((n) {
                    final isSelected = _groupSize == n;
                    return GestureDetector(
                      onTap: () => setState(() => _groupSize = n),
                      child: Container(
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF00B894)
                              : const Color(0xFF2D2D42),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$n',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: Mood.values.length,
                itemBuilder: (_, i) {
                  final m = Mood.values[i];
                  final isSelected = _mood == m;
                  return GestureDetector(
                    onTap: () => setState(() => _mood = m),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? m.color.withValues(alpha: 0.3)
                            : const Color(0xFF2D2D42),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? m.color : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        '${m.emoji} ${m.label}',
                        style: TextStyle(
                          color: isSelected ? m.color : Colors.grey,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            ..._suggestions.map((s) => _SuggestionCard(suggestion: s)),
          ],
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final FoodSuggestion suggestion;
  const _SuggestionCard({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D42),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(suggestion.emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  suggestion.estimatedPrice,
                  style: const TextStyle(
                    color: Color(0xFF00B894),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  suggestion.reason,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Text(
                '${suggestion.matchScore}%',
                style: const TextStyle(
                  color: Color(0xFF00B894),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Text(
                'match',
                style: TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
