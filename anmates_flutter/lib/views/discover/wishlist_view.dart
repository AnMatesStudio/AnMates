import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/wishlist_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anm_widgets.dart';

// Backend AllowedCategories → (Vietnamese label, emoji). Kept in sync with
// anmates-api/services/wishlist.go AllowedCategories.
const _categories = <({String code, String label, String emoji})>[
  (code: 'lau', label: 'Lẩu', emoji: '🍲'),
  (code: 'bbq', label: 'Nướng', emoji: '🥩'),
  (code: 'pho', label: 'Phở', emoji: '🍜'),
  (code: 'bun', label: 'Bún', emoji: '🥢'),
  (code: 'com', label: 'Cơm', emoji: '🍚'),
  (code: 'cafe', label: 'Cafe', emoji: '☕'),
  (code: 'trang_mieng', label: 'Tráng miệng', emoji: '🍰'),
  (code: 'other', label: 'Khác', emoji: '🍽️'),
];

({String label, String emoji}) _catMeta(String code) {
  for (final c in _categories) {
    if (c.code == code) return (label: c.label, emoji: c.emoji);
  }
  return (label: 'Khác', emoji: '🍽️');
}

class WishlistView extends StatefulWidget {
  const WishlistView({super.key});

  @override
  State<WishlistView> createState() => _WishlistViewState();
}

class _WishlistViewState extends State<WishlistView> {
  List<WishlistItem>? _items;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await WishlistService().list();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tải được wishlist. Thử lại nhé.';
        _loading = false;
      });
    }
  }

  Future<void> _openAddSheet() async {
    final result = await showModalBottomSheet<({String name, String category})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddWishlistSheet(),
    );
    if (result == null) return;
    try {
      final item = await WishlistService().add(result.name, result.category);
      if (!mounted) return;
      setState(() => _items = [item, ...?_items]);
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = e.statusCode == 409
          ? 'Món này đã có trong wishlist rồi'
          : 'Thêm món thất bại, thử lại nha';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Thêm món thất bại')));
    }
  }

  Future<void> _delete(WishlistItem item) async {
    final prev = _items;
    setState(() => _items = _items?.where((i) => i.id != item.id).toList());
    try {
      await WishlistService().remove(item.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items = prev); // rollback on failure
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xoá thất bại, thử lại nha')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mint,
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddSheet,
        backgroundColor: AppColors.berry,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final count = _items?.length ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('WISHLIST MÓN ĂN'),
          const SizedBox(height: 6),
          Text(
            '$count món',
            style: AppTextStyles.display(
              size: 30,
              weight: FontWeight.w800,
              color: AppColors.ink,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Thêm món bạn thèm — càng nhiều gu chung, càng dễ match',
            style: AppTextStyles.body(size: 13, color: AppColors.ink50),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.berry),
      );
    }
    if (_error != null) {
      return _centerMessage(
        emoji: '😕',
        title: _error!,
        actionLabel: 'Thử lại',
        onAction: _load,
      );
    }
    final items = _items ?? [];
    if (items.isEmpty) {
      return _centerMessage(
        emoji: '🍽️',
        title: 'Chưa có món nào',
        subtitle: 'Bấm nút + để thêm món bạn thèm.',
        actionLabel: 'Thêm món',
        onAction: _openAddSheet,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) =>
          _WishlistRow(item: items[i], onDelete: () => _delete(items[i])),
    );
  }

  Widget _centerMessage({
    required String emoji,
    required String title,
    String? subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.display(
                size: 20,
                weight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.5,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  size: 14,
                  color: AppColors.ink70,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 24),
            AnmCTA(label: actionLabel, onTap: onAction, fullWidth: false),
          ],
        ),
      ),
    );
  }
}

// ─── Wishlist row ─────────────────────────────────────────────────────────────

class _WishlistRow extends StatelessWidget {
  final WishlistItem item;
  final VoidCallback onDelete;
  const _WishlistRow({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final meta = _catMeta(item.foodCategory);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(meta.emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.foodName,
                  style: AppTextStyles.body(
                    size: 15,
                    weight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  meta.label,
                  style: AppTextStyles.body(size: 12, color: AppColors.ink50),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline,
              color: AppColors.ink50,
              size: 22,
            ),
            tooltip: 'Xoá',
          ),
        ],
      ),
    );
  }
}

// ─── Add sheet ────────────────────────────────────────────────────────────────

class _AddWishlistSheet extends StatefulWidget {
  const _AddWishlistSheet();

  @override
  State<_AddWishlistSheet> createState() => _AddWishlistSheetState();
}

class _AddWishlistSheetState extends State<_AddWishlistSheet> {
  final _ctrl = TextEditingController();
  String _category = _categories.first.code;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (name: name, category: _category));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.ink10,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Eyebrow('THÊM MÓN'),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              maxLength: 100,
              decoration: InputDecoration(
                hintText: 'VD: Lẩu Thái, Bún bò Huế…',
                filled: true,
                fillColor: AppColors.mint,
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Phân loại',
              style: AppTextStyles.body(
                size: 13,
                weight: FontWeight.w700,
                color: AppColors.ink70,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _categories)
                  AnmChip(
                    label: '${c.emoji} ${c.label}',
                    active: _category == c.code,
                    color: AppColors.berry,
                    sm: true,
                    onTap: () => setState(() => _category = c.code),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            AnmCTA(label: 'Thêm vào wishlist', onTap: _submit),
          ],
        ),
      ),
    );
  }
}
