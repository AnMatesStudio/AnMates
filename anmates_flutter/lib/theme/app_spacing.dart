/// Design system spacing tokens
/// Use these instead of hardcoded pixel values for consistency and maintainability
class AppSpacing {
  // Atomic units
  static const xs2 = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xl2 = 24.0;
  static const xl3 = 32.0;
  static const xl4 = 44.0;
  static const xl5 = 56.0;
  static const xl6 = 64.0;

  // Semantic padding/margin combinations
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: lg, vertical: xl2);
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: lg, vertical: md);
  static const EdgeInsets chipPadding = EdgeInsets.symmetric(horizontal: md, vertical: xs);
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(horizontal: lg, vertical: md);
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(horizontal: lg, vertical: md);
}

// Import in analysis_options.yaml to enforce linting:
// linter:
//   rules:
//     - prefer_const_declarations
//     - prefer_const_constructors
