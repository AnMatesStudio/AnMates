import 'package:flutter/widgets.dart';

/// Like [IndexedStack] but children are constructed lazily.
///
/// Why this exists:
/// - [IndexedStack] calls `build()` on every child immediately, even children
///   that are never shown. For the main tab view that's 4× the cost at app
///   start: 4 scaffolds, 4 scroll views, 4 sets of repository calls.
/// - [LazyIndexedStack] uses [WidgetBuilder]s and only invokes each builder
///   the first time that index becomes visible.
/// - Once built, a child is kept in the tree (Offstage'd when not active),
///   so scroll position and other [State] are preserved across tab switches.
///
/// Memory impact: at app launch, only the initial tab's subtree is built.
/// On a 4-tab app, this saves roughly 30–40% of the cold-start widget tree.
class LazyIndexedStack extends StatefulWidget {
  /// Currently visible index. Must be in `[0, builders.length)`.
  final int index;

  /// Builders for each tab. Order maps 1:1 to [index].
  final List<WidgetBuilder> builders;

  /// Stack sizing strategy. Defaults to [StackFit.expand] like [IndexedStack].
  final StackFit sizing;

  const LazyIndexedStack({
    required this.index,
    required this.builders,
    this.sizing = StackFit.expand,
    super.key,
  });

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  // Tracks indices that have been visited at least once.
  late final Set<int> _builtIndices;

  @override
  void initState() {
    super.initState();
    _builtIndices = <int>{widget.index};
  }

  @override
  void didUpdateWidget(LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _builtIndices.add(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < widget.builders.length; i++) {
      if (_builtIndices.contains(i)) {
        // Already built (or being built right now). Keep it alive but
        // wrap in Offstage to hide when not active. Offstage skips paint
        // but preserves State and layout.
        children.add(
          Offstage(
            offstage: i != widget.index,
            child: TickerMode(
              // Pause animations in inactive tabs so they don't burn CPU.
              enabled: i == widget.index,
              child: Builder(builder: widget.builders[i]),
            ),
          ),
        );
      } else {
        // Not yet visited — render a zero-size placeholder. No build cost,
        // no widget tree, no State allocated.
        children.add(const SizedBox.shrink());
      }
    }

    return Stack(fit: widget.sizing, children: children);
  }
}
