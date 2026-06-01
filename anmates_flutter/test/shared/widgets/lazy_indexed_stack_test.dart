import 'package:anmates/shared/widgets/lazy_indexed_stack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LazyIndexedStack', () {
    testWidgets('only the initial active tab is built on first render', (
      tester,
    ) async {
      final buildCounts = <int, int>{0: 0, 1: 0, 2: 0, 3: 0};

      await tester.pumpWidget(
        MaterialApp(
          home: LazyIndexedStack(
            index: 0,
            builders: [
              (_) {
                buildCounts[0] = buildCounts[0]! + 1;
                return const Text('Tab 0');
              },
              (_) {
                buildCounts[1] = buildCounts[1]! + 1;
                return const Text('Tab 1');
              },
              (_) {
                buildCounts[2] = buildCounts[2]! + 1;
                return const Text('Tab 2');
              },
              (_) {
                buildCounts[3] = buildCounts[3]! + 1;
                return const Text('Tab 3');
              },
            ],
          ),
        ),
      );

      // Only tab 0 should have been built. The other 3 are SizedBox.shrink.
      expect(buildCounts[0], 1);
      expect(buildCounts[1], 0);
      expect(buildCounts[2], 0);
      expect(buildCounts[3], 0);
    });

    testWidgets('visiting an unvisited tab triggers its build', (tester) async {
      int tab1Builds = 0;
      var currentIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: LazyIndexedStack(
                  index: currentIndex,
                  builders: [
                    (_) => const Text('Tab 0'),
                    (_) {
                      tab1Builds++;
                      return const Text('Tab 1');
                    },
                  ],
                ),
                floatingActionButton: FloatingActionButton(
                  onPressed: () => setState(() => currentIndex = 1),
                ),
              );
            },
          ),
        ),
      );

      expect(tab1Builds, 0);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      expect(tab1Builds, 1);
      expect(find.text('Tab 1'), findsOneWidget);
    });

    testWidgets('previously built tabs keep their State across switches', (
      tester,
    ) async {
      var currentIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: LazyIndexedStack(
                  index: currentIndex,
                  builders: [
                    (_) => const _CounterWidget(label: 'A'),
                    (_) => const _CounterWidget(label: 'B'),
                  ],
                ),
                floatingActionButton: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FloatingActionButton(
                      heroTag: 'switch',
                      onPressed: () =>
                          setState(() => currentIndex = 1 - currentIndex),
                      child: const Icon(Icons.swap_horiz),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Tap the inner counter button on tab A 3 times.
      // Find by widget type (the text changes after each tap, so we can't
      // re-use a text finder).
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byType(TextButton));
        await tester.pump();
      }
      // Now should see "A: 3"
      expect(find.text('A: 3'), findsOneWidget);

      // Switch to tab B, then back to tab A
      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pump();

      // Tab A's state should be preserved: still shows "A: 3"
      expect(find.text('A: 3'), findsOneWidget);
    });
  });
}

/// Minimal stateful widget for the keep-alive test.
class _CounterWidget extends StatefulWidget {
  final String label;
  const _CounterWidget({required this.label});

  @override
  State<_CounterWidget> createState() => _CounterWidgetState();
}

class _CounterWidgetState extends State<_CounterWidget> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => setState(() => _count++),
        child: Text('${widget.label}: $_count'),
      ),
    );
  }
}
