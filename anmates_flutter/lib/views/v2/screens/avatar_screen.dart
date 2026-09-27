import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../../../widgets/v2/avatar_cropper.dart';
import '../../../widgets/v2/filter_parts.dart';
import '../../../widgets/v2/photo_viewer.dart';
import '../v2_data.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **Ảnh đại diện** — opened from the avatar on Me. Upload a photo from the
/// device, then move and zoom it inside the circle; or pick one of the
/// app's illustrations ([kAvatarSamples]) instead of a personal photo.
/// The photo is stored on our own API (PUT /profile/avatar), a sample as
/// `avatar_url = 'asset:<path>'` — partners see either one.
class AvatarScreen extends StatefulWidget {
  const AvatarScreen({super.key});

  @override
  State<AvatarScreen> createState() => _AvatarScreenState();
}

class _AvatarScreenState extends State<AvatarScreen> {
  /// The sample tapped in the grid; starts on my current one, if it is a sample.
  String? _picked;

  /// Set once a photo is picked: the crop step replaces the chooser.
  AvatarCropController? _crop;

  bool _loading = false; // picking + decoding a photo
  bool _rendering = false; // drawing the crop before the upload
  bool _failed = false; // the last save failed
  bool _unreadable = false; // the picked file wasn't an image we can decode

  @override
  void initState() {
    super.initState();
    final current = context.read<V2State>().myAvatarUrl;
    if (current != null && current.startsWith('asset:')) {
      _picked = current.substring('asset:'.length);
    }
  }

  @override
  void dispose() {
    _dropCrop();
    super.dispose();
  }

  void _dropCrop() {
    _crop?.image.dispose();
    _crop?.dispose();
    _crop = null;
  }

  Future<void> _pickPhoto() async {
    final s = context.read<V2State>();
    setState(() {
      _loading = true;
      _unreadable = false;
    });
    final bytes = await s.pickAvatarPhoto();
    if (!mounted) return;
    if (bytes == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final image = await decodeForCrop(bytes);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _dropCrop();
        _crop = AvatarCropController(image);
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _unreadable = true;
        });
      }
    }
  }

  Future<void> _save() async {
    final s = context.read<V2State>();
    if (s.avatarSaving || _rendering) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final bottom = navClearance(context);

    final bool ok;
    final crop = _crop;
    if (crop != null) {
      setState(() => _rendering = true);
      final png = await renderCrop(crop.image, crop.frame.sourceRect);
      if (!mounted) return;
      setState(() => _rendering = false);
      ok = await s.uploadAvatarCrop(png);
    } else {
      final picked = _picked;
      if (picked == null || 'asset:$picked' == s.myAvatarUrl) {
        s.go(V2Screen.me); // nothing changed
        return;
      }
      ok = await s.chooseAvatarSample(picked);
    }
    if (!mounted) return;
    if (ok) {
      showV2Toast(messenger, s.t('Đã cập nhật ảnh đại diện', 'Profile photo updated'), bottom: bottom);
      s.go(V2Screen.me);
    } else {
      setState(() => _failed = true);
    }
  }

  void _back() {
    final s = context.read<V2State>();
    if (_crop != null) {
      setState(() {
        _dropCrop();
        _failed = false;
      });
      return;
    }
    s.clearAvatarError();
    s.go(V2Screen.me);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();
    final busy = s.avatarSaving || _rendering;
    final crop = _crop;

    return FilterLayout(
      header: FilterHeader(title: s.t('Ảnh đại diện', 'Profile photo'), onBack: _back),
      cta: V2Cta(
        key: const Key('avatar-save'),
        label: busy
            ? s.t('Đang lưu…', 'Saving…')
            : crop != null
                ? s.t('Dùng ảnh này', 'Use this photo')
                : s.t('Lưu ảnh đại diện', 'Save profile photo'),
        height: 54,
        radius: 20,
        fontSize: 15.5,
        onTap: _save,
      ),
      sheet: V2Sheet(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (crop != null) ..._cropStep(s, crop) else ..._chooser(s),
            if (_failed && s.avatarError != null) ...[
              const SizedBox(height: 14),
              Text(
                s.avatarError!,
                textAlign: TextAlign.center,
                style: AppTextV2.name(color: AppColorsV2.alert, size: 12.5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _chooser(V2State s) {
    final preview = _picked != null ? 'asset:$_picked' : s.myAvatarUrl;
    // Only an uploaded photo opens full size; an illustration is all there is.
    final viewable = isUploadedAvatar(preview);
    return [
      Center(
        child: Semantics(
          container: true,
          button: viewable,
          label: viewable ? s.t('Xem ảnh đại diện', 'View profile photo') : null,
          child: GestureDetector(
            key: const Key('avatar-preview'),
            onTap: viewable
                ? () => showPhotoViewer(context, [avatarSourceOf(preview).network!])
                : null,
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 132,
                height: 132,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0A285A).withValues(alpha: 0.2),
                      blurRadius: 26,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: AvatarImage(url: preview),
              ),
              if (viewable)
                Positioned(
                  right: 4,
                  bottom: 6,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColorsV2.ink.withValues(alpha: 0.72),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.zoom_out_map_rounded, size: 15, color: Colors.white),
                  ),
                ),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 18),
      V2TapTarget(
        key: const Key('avatar-upload'),
        onTap: _loading ? null : _pickPhoto,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppColorsV2.wisteriaTint,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (_loading)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColorsV2.wisteria),
              )
            else
              const Icon(Icons.photo_library_rounded, size: 20, color: AppColorsV2.wisteria),
            const SizedBox(width: 8),
            Text(s.t('Tải ảnh lên', 'Upload a photo'),
                style: AppTextV2.name(color: AppColorsV2.wisteria, size: 13.5)),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      _hint(_unreadable
          ? s.t('Không đọc được ảnh này. Chọn ảnh JPG hoặc PNG khác nhé.',
              "Couldn't read that file. Pick another JPG or PNG.")
          : s.t('Ảnh từ máy bạn — bước sau kéo để căn, phóng to thu nhỏ trong khung tròn.',
              'A photo from your device — next you move and zoom it inside the circle.')),
      const SizedBox(height: 22),
      Text(s.t('Hoặc chọn ảnh có sẵn', 'Or pick an illustration'), style: AppTextV2.name(size: 13)),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, box) {
        const gap = 10.0;
        final tile = ((box.maxWidth - gap * 3) / 4).floorToDouble();
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (var i = 0; i < kAvatarSamples.length; i++)
            _SampleTile(
              key: Key('avatar-sample-$i'),
              asset: kAvatarSamples[i],
              size: tile,
              selected: _picked == kAvatarSamples[i],
              label: s.t('Ảnh có sẵn ${i + 1}', 'Illustration ${i + 1}'),
              onTap: () => setState(() {
                _picked = kAvatarSamples[i];
                _failed = false;
              }),
            ),
        ]);
      }),
    ];
  }

  List<Widget> _cropStep(V2State s, AvatarCropController crop) {
    return [
      AvatarCropper(key: const Key('avatar-cropper'), controller: crop),
      const SizedBox(height: 10),
      _hint(s.t('Kéo để căn ảnh · chụm hai ngón hoặc cuộn chuột để phóng to',
          'Drag to position · pinch or scroll to zoom')),
      const SizedBox(height: 6),
      ListenableBuilder(
        listenable: crop,
        builder: (context, _) => Row(children: [
          _ZoomButton(
            key: const Key('avatar-zoom-out'),
            icon: Icons.remove_rounded,
            label: s.t('Thu nhỏ', 'Zoom out'),
            onTap: () => crop.zoomTo(crop.zoom - 0.25),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColorsV2.wisteria,
                thumbColor: Colors.white,
                inactiveTrackColor: AppColorsV2.inkA(0.08),
                overlayColor: AppColorsV2.wisteria.withValues(alpha: 0.12),
              ),
              child: Slider(
                key: const Key('avatar-zoom'),
                value: crop.zoom,
                min: 1,
                max: CropFrame.maxZoom,
                onChanged: crop.zoomTo,
              ),
            ),
          ),
          _ZoomButton(
            key: const Key('avatar-zoom-in'),
            icon: Icons.add_rounded,
            label: s.t('Phóng to', 'Zoom in'),
            onTap: () => crop.zoomTo(crop.zoom + 0.25),
          ),
        ]),
      ),
      const SizedBox(height: 4),
      Center(
        child: V2TapTarget(
          onTap: _loading ? null : _pickPhoto,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(s.t('Chọn ảnh khác', 'Pick another photo'),
                style: AppTextV2.name(color: AppColorsV2.wisteria, size: 12.5)),
          ),
        ),
      ),
    ];
  }

  static Widget _hint(String text) => Text(
        text,
        textAlign: TextAlign.center,
        style: AppTextV2.meta(color: AppColorsV2.inkA(0.45)).copyWith(fontSize: 11),
      );
}

class _SampleTile extends StatelessWidget {
  const _SampleTile({
    super.key,
    required this.asset,
    required this.size,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final String asset;
  final double size;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: size,
            height: size,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: selected ? AppColorsV2.wisteria : AppColorsV2.inkA(0.08),
                width: selected ? 3 : 1.5,
              ),
            ),
            child: ClipOval(child: Image.asset(asset, fit: BoxFit.cover)),
          ),
          if (selected)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColorsV2.wisteria,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
              ),
            ),
        ]),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: V2TapTarget(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColorsV2.inkA(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: AppColorsV2.inkA(0.7)),
        ),
      ),
    );
  }
}
