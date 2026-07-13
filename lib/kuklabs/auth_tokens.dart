/// Exact auth-page control sizes + type scale from the shared Kuklabs standard
/// (docs/kuklabs/KUKLABS_DESIGN_TOKENS.json → authPage). Never hardcode new
/// sizes when a token exists here.
class AuthTokens {
  AuthTokens._();

  // Layout
  static const double contentMaxWidth = 420;
  static const double horizontalPadding = 20;
  static const double productIcon = 88; // 80–88
  static const double productIconRadius = 24;

  // Controls
  static const double tabsHeight = 56;
  static const double inputHeight = 58;
  static const double buttonHeight = 58;
  static const double googleButtonHeight = 58;
  static const double authControlRadius = 16;
  static const double orDividerHeight = 24;

  // Type scale
  static const double welcomeSize = 24;
  static const double welcomeHeight = 30 / 24;
  static const double productNameSize = 38;
  static const double productNameHeight = 44 / 38;
  static const double taglineSize = 15;
  static const double taglineHeight = 22 / 15;
  static const double tabLabelSize = 16;
  static const double inputTextSize = 16;
  static const double primaryButtonTextSize = 17;
  static const double legalTextSize = 13;
  static const double poweredBySize = 13;
}
