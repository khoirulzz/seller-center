import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/ns_colors.dart';
import '../../../core/theme/ns_spacing.dart';
import '../../../core/theme/ns_typography.dart';
import '../../../core/widgets/ns_widgets.dart';
import '../../state/seller_app_state.dart';
import '../stores/store_screens.dart';

/// Paints the entire status-bar inset as part of the seller's brand header.
///
/// Scaffold allocates the system top inset above an appBar. The colored
/// surface therefore belongs OUTSIDE SafeArea, not inside its content.
class SellerTopBar extends StatelessWidget implements PreferredSizeWidget {
  const SellerTopBar({
    super.key,
    required this.appState,
    required this.storeTargetKey,
    required this.availableWidth,
  });

  final SellerAppState appState;
  final GlobalKey storeTargetKey;
  final double availableWidth;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final activeStore = appState.activeStore;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: ColoredBox(
        key: const Key('seller-header-surface'),
        color: NsColors.brandAction,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: preferredSize.height,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: NsSpacing.horizontalPaddingForWidth(availableWidth),
              ),
              child: Row(
                children: [
                  const NsBrandMark(size: 30, color: Colors.white),
                  const SizedBox(width: NsSpacing.sm),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label:
                          'Toko aktif ${activeStore?.name ?? "Pilih toko"}, ketuk untuk mengganti toko',
                      child: InkWell(
                        key: storeTargetKey,
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => showNsStoreSwitcherSheet(
                          context: context,
                          appState: appState,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    activeStore?.name ?? 'Pilih toko',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: NsTypography.titleSm.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const NsIcon(
                                  'chevron-down',
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (activeStore != null)
                    NsIconButton(
                      key: const Key('seller-chat-action'),
                      color: Colors.white,
                      iconName: 'message-circle',
                      semanticLabel: 'Chat pelanggan',
                      onPressed: () => context.push('/chat'),
                    ),
                  NsIconButton(
                    key: const Key('seller-notification-action'),
                    color: Colors.white,
                    iconName: 'bell',
                    semanticLabel: 'Notifikasi',
                    badgeCount: appState.unreadNotificationCount,
                    badgeBackgroundColor: Colors.white,
                    badgeForegroundColor: NsColors.brandAction,
                    onPressed: () => context.push('/notifications'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
