import 'dart:typed_data';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/onboarding_draft.dart';
import '../../services/profile_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anm_widgets.dart';

/// Screen 11 — "Show bản thân nào" (step 6/6).
/// Chọn ảnh chính (bắt buộc) + tối đa 2 ảnh phụ có caption.
/// "Hoàn tất" validate toàn bộ 4 màn + upload Firebase Storage + 1 API call.
class PhotoUploadView extends StatefulWidget {
  final VoidCallback onComplete;
  const PhotoUploadView({super.key, required this.onComplete});

  @override
  State<PhotoUploadView> createState() => _PhotoUploadViewState();
}

class _PhotoUploadViewState extends State<PhotoUploadView> {
  final _draft = OnboardingDraftController.instance;
  final _picker = ImagePicker();
  bool _submitting = false;

  Future<void> _pick(ImageSource source) async {
    try {
      final x = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 85,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        final photo = DraftPhoto(bytes: bytes);
        if (_draft.mainPhoto == null) {
          _draft.mainPhoto = photo;
          _draft.photoError = null;
        } else if (_draft.extraPhotos.length <
            OnboardingDraftController.maxExtraPhotos) {
          _draft.extraPhotos.add(photo);
        } else {
          _snack('Đã đủ ${OnboardingDraftController.maxExtraPhotos + 1} ảnh');
        }
      });
    } catch (e) {
      _snack('Không mở được ảnh: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> _instagramTodo() => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.berry.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.camera,
                    color: AppColors.berry, size: 24),
              ),
              const SizedBox(height: 14),
              Text(
                'Tính năng đang phát triển',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kết nối Instagram chưa khả dụng. Bạn có thể chọn ảnh từ Thư viện.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  size: 13,
                  color: AppColors.ink50,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.berry,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Đã hiểu',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  void _removeMain() => setState(() => _draft.mainPhoto = null);
  void _removeExtra(int i) => setState(() => _draft.extraPhotos.removeAt(i));

  void _showPreview(Uint8List bytes) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _PhotoPreviewDialog(bytes: bytes),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.berry,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _finish() async {
    if (_submitting) return;
    if (!_draft.validateStep08()) {
      _snack('Bạn chưa nhập đủ Thông tin cá nhân (bước 3)');
      Navigator.of(context).popUntil(ModalRoute.withName('onb_profile'));
      return;
    }
    if (!_draft.validateStep09()) {
      _snack('Bạn chưa chọn đủ Gú ẩm thực (bước 4)');
      Navigator.of(context).popUntil(ModalRoute.withName('onb_food'));
      return;
    }
    if (!_draft.validateVibeScreen()) {
      _snack('Bạn chưa chọn đủ Vibe (bước 5)');
      Navigator.of(context).popUntil(ModalRoute.withName('onb_vibe'));
      return;
    }
    // Null-safe check — guards against edge-case where photo is cleared
    // between validation and upload (e.g., rapid double-tap).
    final mainPhoto = _draft.mainPhoto;
    if (mainPhoto == null) {
      setState(() => _draft.photoError = 'Bạn chưa chọn Ảnh chính');
      return;
    }

    setState(() => _submitting = true);
    try {
      final mainUrl = mainPhoto.uploadedUrl ??
          await StorageService().uploadPhoto(mainPhoto.bytes, slot: 'main');
      mainPhoto.uploadedUrl = mainUrl;

      final photos = <Map<String, dynamic>>[];
      for (var i = 0; i < _draft.extraPhotos.length; i++) {
        final p = _draft.extraPhotos[i];
        final url = p.uploadedUrl ??
            await StorageService().uploadPhoto(p.bytes, slot: 'extra$i');
        p.uploadedUrl = url;
        photos.add({'url': url, 'caption': p.caption});
      }

      await ProfileService().completeOnboarding(
        name: _draft.name,
        nickname: _draft.nickname,
        birthDate: _draft.dob,
        personalityScore: _draft.personality.round(),
        foodTags: _draft.food.toList(),
        vibeTags: _draft.vibe.toList(),
        avatarUrl: mainUrl,
        photos: photos,
      );

      await _draft.reset();
      if (!mounted) return;
      widget.onComplete();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack('Gửi hồ sơ thất bại: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(step: 6, total: 6),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('BƯỚC CUỐI · MÔ TẢ BẢN THÂN'),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'Show bản thân nào',
                            style: AppTextStyles.display(
                              size: 28,
                              weight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('✨', style: TextStyle(fontSize: 22)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tối đa ${OnboardingDraftController.maxExtraPhotos + 1} tấm — '
                      'chọn những khoảnh khắc kể nhiều về bạn nhất. '
                      'Mate ăn cùng sẽ thấy tấm đầu tiên.',
                      style: AppTextStyles.body(
                        size: 14,
                        color: AppColors.ink70,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Photo grid ──────────────────────────────────────────
                    _PhotoGrid(
                      draft: _draft,
                      onPickMain: () => _pick(ImageSource.gallery),
                      onAddExtra: () => _pick(ImageSource.gallery),
                      onRemoveMain: _removeMain,
                      onRemoveExtra: _removeExtra,
                      onCaption: (i, v) => _draft.extraPhotos[i].caption = v,
                      onPreview: _showPreview,
                    ),
                    if (_draft.photoError != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.error_outline,
                              size: 13, color: Colors.red.shade600),
                          const SizedBox(width: 5),
                          Text(
                            _draft.photoError!,
                            style: AppTextStyles.body(
                              size: 12,
                              color: Colors.red.shade600,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),

                    // ── Tips card ───────────────────────────────────────────
                    const _TipsCard(),
                    const SizedBox(height: 10),

                    // ── Source buttons ──────────────────────────────────────
                    _SourceRow(
                      onCamera: () => _pick(ImageSource.camera),
                      onGallery: () => _pick(ImageSource.gallery),
                      onInstagram: _instagramTodo,
                    ),
                  ],
                ),
              ),
            ),
            _BottomBar(
              count: _draft.photoCount,
              total: OnboardingDraftController.maxExtraPhotos + 1,
              submitting: _submitting,
              onFinish: _finish,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Photo grid ───────────────────────────────────────────────────────────────
class _PhotoGrid extends StatelessWidget {
  final OnboardingDraftController draft;
  final VoidCallback onPickMain;
  final VoidCallback onAddExtra;
  final VoidCallback onRemoveMain;
  final void Function(int) onRemoveExtra;
  final void Function(int, String) onCaption;
  final void Function(Uint8List) onPreview;

  const _PhotoGrid({
    required this.draft,
    required this.onPickMain,
    required this.onAddExtra,
    required this.onRemoveMain,
    required this.onRemoveExtra,
    required this.onCaption,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 290,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: _MainCard(
              photo: draft.mainPhoto,
              onPick: onPickMain,
              onRemove: onRemoveMain,
              onPreview: onPreview,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _RightSlot(
                    index: 0,
                    draft: draft,
                    onAdd: onAddExtra,
                    onRemove: onRemoveExtra,
                    onCaption: onCaption,
                    onPreview: onPreview,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _RightSlot(
                    index: 1,
                    draft: draft,
                    onAdd: onAddExtra,
                    onRemove: onRemoveExtra,
                    onCaption: onCaption,
                    onPreview: onPreview,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Main (Ảnh chính) card ────────────────────────────────────────────────────
class _MainCard extends StatelessWidget {
  final DraftPhoto? photo;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final void Function(Uint8List) onPreview;
  const _MainCard({
    required this.photo,
    required this.onPick,
    required this.onRemove,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final filled = photo != null;
    return GestureDetector(
        onTap: filled ? () => onPreview(photo!.bytes) : onPick,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: AppColors.berryTint,
            border: Border.all(
              color: filled
                  ? Colors.transparent
                  : AppColors.berry.withValues(alpha: 0.35),
              width: 1.4,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (filled)
                Image.memory(photo!.bytes, fit: BoxFit.cover)
              else
                CustomPaint(painter: _StripePainter()),
              // "+ MAIN" badge top-left
              Positioned(
                top: 10,
                left: 10,
                child: _Badge(
                  text: filled ? 'MAIN' : '+ MAIN',
                  color: AppColors.berry,
                ),
              ),
              // X remove button top-right
              if (filled)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _RemoveBtn(onTap: onRemove),
                ),
              // Camera icon placeholder
              if (!filled)
                const Center(
                  child: Icon(Icons.add_a_photo_outlined,
                      color: AppColors.berry, size: 32),
                ),
              // "Ảnh chính" label bottom-left
              Positioned(
                left: 10,
                bottom: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: filled
                        ? Colors.black.withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Ảnh chính',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: filled ? Colors.white : AppColors.ink70,
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

// ─── Extra photo slot (image + caption below) ────────────────────────────────
class _RightSlot extends StatelessWidget {
  final int index;
  final OnboardingDraftController draft;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  final void Function(int, String) onCaption;
  final void Function(Uint8List) onPreview;

  const _RightSlot({
    required this.index,
    required this.draft,
    required this.onAdd,
    required this.onRemove,
    required this.onCaption,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = index < draft.extraPhotos.length;

    if (hasPhoto) {
      final p = draft.extraPhotos[index];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onPreview(p.bytes),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(p.bytes, fit: BoxFit.cover),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: _Badge(
                        text: '0${index + 2}',
                        color: Colors.black.withValues(alpha: 0.50),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _RemoveBtn(onTap: () => onRemove(index)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 2),
            child: Row(
              children: [
                Expanded(
                  child: _CaptionField(
                    key: ValueKey(p),
                    initial: p.caption ?? '',
                    onChanged: (v) => onCaption(index, v),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.edit_outlined,
                    size: 11, color: AppColors.ink30),
              ],
            ),
          ),
        ],
      );
    }

    // Only the first empty slot shows the "Thêm ảnh" dashed card
    final isFirstEmpty = index == draft.extraPhotos.length;
    if (!isFirstEmpty) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: AppColors.mintWarm,
          border: Border.all(color: AppColors.ink10),
        ),
      );
    }

    return GestureDetector(
      onTap: onAdd,
      child: DottedBorderBox(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.berry,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 18),
              ),
              const SizedBox(height: 5),
              Text(
                'Thêm ảnh',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink70,
                ),
              ),
              Text(
                'sở thích',
                style: AppTextStyles.mono(
                  size: 8,
                  weight: FontWeight.w600,
                  color: AppColors.ink50,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      );
  }
}

// ─── Caption field ────────────────────────────────────────────────────────────
class _CaptionField extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onChanged;
  const _CaptionField(
      {super.key, required this.initial, required this.onChanged});

  @override
  State<_CaptionField> createState() => _CaptionFieldState();
}

class _CaptionFieldState extends State<_CaptionField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      onChanged: widget.onChanged,
      style: GoogleFonts.beVietnamPro(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.ink70,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        hintText: 'Thêm chú thích…',
        hintStyle: GoogleFonts.beVietnamPro(
            fontSize: 11, color: AppColors.ink30),
      ),
    );
  }
}

// ─── Tips card ────────────────────────────────────────────────────────────────
class _TipsCard extends StatelessWidget {
  const _TipsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.berryTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.berry.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.berry,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.auto_awesome,
                    size: 12, color: Colors.white),
              ),
              const SizedBox(width: 7),
              Text(
                "Mẹo chọn ảnh cho 'Ăn Mate'",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          _tip(true, 'Một ảnh đẹp mặt chính, show-off bản thân ra nào!'),
          _tip(true, 'Một ảnh quán ăn / quán cafe vibe quán Mate yêu!'),
          _tip(true, 'Một ảnh sở thích, du lịch, thú cưng...'),
          _tip(
            false,
            'Tránh ảnh nhóm, ảnh có hiển thị số điện thoại, thông tin cá nhân',
          ),
        ],
      ),
    );
  }

  Widget _tip(bool ok, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.cancel,
            size: 13,
            color: ok ? const Color(0xFF2ECC71) : AppColors.ink30,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body(
                size: 11,
                color: AppColors.ink70,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Source buttons ───────────────────────────────────────────────────────────
class _SourceRow extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onInstagram;
  const _SourceRow({
    required this.onCamera,
    required this.onGallery,
    required this.onInstagram,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SourceBtn(
            assetPath: 'assets/icons/camera.png',
            label: 'Chụp mới',
            onTap: onCamera,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SourceBtn(
            assetPath: 'assets/icons/photo_ios.png',
            label: 'Thư viện',
            onTap: onGallery,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SourceBtn(
            assetPath: 'assets/icons/instagram.png',
            label: 'Instagram',
            onTap: onInstagram,
          ),
        ),
      ],
    );
  }
}

class _SourceBtn extends StatelessWidget {
  final String assetPath;
  final String label;
  final VoidCallback onTap;
  const _SourceBtn(
      {required this.assetPath, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.ink10),
        ),
        child: Column(
          children: [
            Image.asset(assetPath, width: 36, height: 36),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.beVietnamPro(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.ink70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _RemoveBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _RemoveBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, size: 14, color: Colors.white),
      ),
    );
  }
}

/// Dashed border container for the "Thêm ảnh" add slot.
class DottedBorderBox extends StatelessWidget {
  final Widget child;
  const DottedBorderBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.berry.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.berry.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rrect =
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14));
    final path = Path()..addRRect(rrect);
    const dash = 5.0, gap = 4.0;
    for (final m in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < m.length) {
        canvas.drawPath(m.extractPath(dist, dist + dash), paint);
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRectPainter _) => false;
}

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Soft blush background
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFFF9EEF4));
    // Berry-tinted diagonal stripes (bottom-left → top-right)
    final stripe = Paint()
      ..color = AppColors.berry.withValues(alpha: 0.10)
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke;
    final span = size.width + size.height;
    for (double x = -size.height; x < span; x += 28) {
      canvas.drawLine(
          Offset(x, 0), Offset(x + size.height, size.height), stripe);
    }
  }

  @override
  bool shouldRepaint(_StripePainter _) => false;
}

// ─── Full-screen photo preview dialog ────────────────────────────────────────
class _PhotoPreviewDialog extends StatelessWidget {
  final Uint8List bytes;
  const _PhotoPreviewDialog({required this.bytes});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Tap outside image → dismiss
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Pinch-to-zoom image
            Center(
              child: GestureDetector(
                // Prevent dismiss when tapping the image itself
                onTap: () {},
                child: Hero(
                  tag: 'photo_preview',
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            // Close button top-right
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
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

// ─── Top bar ──────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final int step;
  final int total;
  const _TopBar({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink10,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back,
                  size: 20, color: AppColors.ink),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: step / total,
                minHeight: 5,
                backgroundColor: AppColors.ink10,
                valueColor: const AlwaysStoppedAnimation(AppColors.berry),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$step/$total',
            style: AppTextStyles.mono(
              size: 12,
              weight: FontWeight.w700,
              color: AppColors.ink50,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom bar ───────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final int count;
  final int total;
  final bool submitting;
  final VoidCallback onFinish;
  const _BottomBar({
    required this.count,
    required this.total,
    required this.submitting,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.ink10, width: 0.5)),
      ),
      child: Row(
        children: [
          Text(
            '$count / $total ảnh',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: count > 0 ? AppColors.berry : AppColors.ink50,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 160,
            child: AnmCTA(
              label: submitting ? 'Đang gửi…' : 'Hoàn tất  ✨',
              onTap: (submitting || count == 0) ? null : onFinish,
              background: (submitting || count == 0)
                  ? AppColors.ink30
                  : AppColors.berry,
            ),
          ),
        ],
      ),
    );
  }
}
