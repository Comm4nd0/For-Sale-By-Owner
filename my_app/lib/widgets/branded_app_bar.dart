import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../constants/app_theme.dart';

/// Compact logo widget for use in AppBars across the app.
class AppBarLogo extends StatelessWidget {
  const AppBarLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.goldWarm, AppTheme.goldEmber],
            ),
            borderRadius: BorderRadius.circular(7),
          ),
          child: const PhosphorIcon(PhosphorIconsDuotone.house, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'For Sale',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.15,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'BY OWNER',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w400,
                color: Colors.white.withAlpha(200),
                letterSpacing: 2.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Helper to build a consistently branded AppBar with logo and optional home button.
class BrandedAppBar {
  /// Builds an AppBar with the FSBO logo as the title.
  ///
  /// [context] is required when [showHomeButton] is true.
  /// [showHomeButton] adds a home icon that navigates back to the main shell.
  /// [actions] are additional action buttons (appended after home button if present).
  /// [bottom] is for widgets like TabBar below the AppBar.
  /// [leading] overrides the default leading widget.
  static AppBar build({
    required BuildContext context,
    List<Widget>? actions,
    PreferredSizeWidget? bottom,
    bool showHomeButton = false,
    Widget? leading,
    bool automaticallyImplyLeading = true,
  }) {
    final allActions = <Widget>[];

    if (actions != null) {
      allActions.addAll(actions);
    }

    if (showHomeButton) {
      allActions.add(
        IconButton(
          icon: PhosphorIcon(PhosphorIconsDuotone.house),
          tooltip: 'Home',
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      );
    }

    return AppBar(
      title: const AppBarLogo(),
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: allActions.isEmpty ? null : allActions,
      bottom: bottom,
    );
  }
}
