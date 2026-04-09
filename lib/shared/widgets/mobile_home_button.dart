import 'package:flutter/material.dart';

import '../../routes/app_router.dart';
import '../utils/responsive_utils.dart';

void navigateToMobileHome(BuildContext context) {
  Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.home, (_) => false);
}

Widget? buildMobileHomeLeading(BuildContext context, {bool enabled = true}) {
  if (!enabled || !context.isMobile) return null;

  return IconButton(
    icon: const Icon(Icons.home_rounded),
    tooltip: 'หน้าหลัก',
    onPressed: () => navigateToMobileHome(context),
  );
}

Widget buildMobileHomeCompactButton(
  BuildContext context, {
  bool isDark = false,
}) {
  return InkWell(
    onTap: () => navigateToMobileHome(context),
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
        ),
      ),
      child: Icon(
        Icons.home_rounded,
        size: 16,
        color: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF666666),
      ),
    ),
  );
}

Widget buildMobileCloseCompactButton(
  BuildContext context, {
  bool isDark = false,
  VoidCallback? onPressed,
}) {
  return InkWell(
    onTap: onPressed ?? () => Navigator.of(context).maybePop(),
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
        ),
      ),
      child: Icon(
        Icons.close_rounded,
        size: 16,
        color: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF666666),
      ),
    ),
  );
}

bool useDefaultBackLeading(BuildContext context, bool canPop) {
  return !context.isMobile && canPop;
}
