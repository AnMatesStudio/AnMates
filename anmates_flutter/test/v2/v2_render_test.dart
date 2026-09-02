import 'package:anmates/views/v2/v2_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('v2 app boots at the design frame size', (tester) async {
    // The canvas pins every frame at 402 × 874.
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: V2App()));
    await tester.pump(const Duration(milliseconds: 300));

    // Boots on the onboarding welcome arch, as the design does.
    expect(find.text('CÙNG ĂN THÔI'), findsOneWidget);
    // Fonts are fetched over the network by google_fonts; offline runs report
    // that failure, which is environmental and not a layout defect. Any
    // RenderFlex overflow, by contrast, fails the test through the binding.
  });
}
