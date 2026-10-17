import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/motion/ns_haptics.dart';
import '../../../core/theme/ns_colors.dart';
import '../../../core/theme/ns_spacing.dart';
import '../../../core/theme/ns_typography.dart';
import '../../../core/widgets/ns_widgets.dart';
import '../../../core/widgets/ns_root_back_guard.dart';
import '../../state/seller_app_state.dart';
import '../stores/store_screens.dart';
import '../onboarding/seller_feature_guide.dart';
import '../updates/app_update_screen.dart';

/// AppShell 5 tab tetap (`desain.md` Bab 5.1 & `PRD` Bab 6.1):
/// Beranda, Pesanan, Produk, Analitik, Toko.
/// Mendukung layout adaptif (`LayoutBuilder`) dengan `NavigationRail` pada layar >= 600dp.
class SellerAppShell extends StatelessWidget {
  const SellerAppShell({
    super.key,
    required this.navigationShell,
    required this.appState,
    required this.location,
  });

  final StatefulNavigationShell navigationShell;
  final SellerAppState appState;
  final String location;

  static const List<({String label, String icon})> _tabs = [
    (label: 'Beranda', icon: 'home'),
    (label: 'Pesanan', icon: 'orders'),
    (label: 'Produk', icon: 'box'),
    (label: 'Analitik', icon: 'chart'),
    (label: 'Toko', icon: 'store'),
  ];

  void _onSelectTab(int index) {
    NsHaptics.selection();
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SellerFeatureGuide(
      userId: appState.user?.id,
      eligible: appState.lifecycle == AuthLifecycleState.authenticatedReady &&
          appState.activeStore != null &&
          const ['/beranda', '/pesanan', '/produk', '/analitik', '/toko']
              .contains(location),
      showAnalytics: appState.activeRole.canViewCustomersAndAnalytics,
      builder: (context, guide) => ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final activeStore = appState.activeStore;
        return LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 600;
            return NsRootBackGuard(
              isHome: navigationShell.currentIndex == 0,
              goHome: () => navigationShell.goBranch(0),
              child: Scaffold(
                appBar: PreferredSize(
                  preferredSize: const Size.fromHeight(60),
                  child: SafeArea(
                    bottom: false,
                    child: Container(
                      height: 60,
                      padding: EdgeInsets.symmetric(
                        horizontal: NsSpacing.horizontalPaddingForWidth(
                          constraints.maxWidth,
                        ),
                      ),
                      decoration: const BoxDecoration(
                        color: NsColors.surfaceCanvas,
                        border: Border(
                          bottom: BorderSide(color: NsColors.borderDefault),
                        ),
                      ),
                      child: Row(
                        children: [
                          const NsBrandMark(size: 30),
                          const SizedBox(width: NsSpacing.sm),
                          Expanded(
                            child: Semantics(
                              button: true,
                              label:
                                  'Toko aktif ${activeStore?.name ?? "Pilih toko"}, ketuk untuk mengganti toko',
                              child: InkWell(
                                key: guide.store,
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => showNsStoreSwitcherSheet(
                                  context: context,
                                  appState: appState,
                                ),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: 48,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            activeStore?.name ?? 'Pilih toko',
                                            overflow: TextOverflow.ellipsis,
                                            style: NsTypography.titleSm,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const NsIcon(
                                          'chevron-down',
                                          size: 16,
                                          color: NsColors.textSecondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          NsIconButton(
                            iconName: 'bell',
                            semanticLabel: 'Notifikasi',
                            badgeCount: appState.unreadNotificationCount,
                            onPressed: () => context.push('/notifications'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                body: Column(
                  children: [
                    const AppUpdateNotice(),
                    NsConnectivityStrip(
                      isOffline: appState.isOffline,
                      onRetry: () {
                        appState.setOfflineStatus(false);
                        appState.notifyStoreDataMutated();
                      },
                    ),
                    Expanded(
                      child: isTablet
                          ? Row(
                              children: [
                                NavigationRail(
                                  scrollable: true,
                                  backgroundColor: NsColors.surfaceCanvas,
                                  selectedIndex: navigationShell.currentIndex,
                                  onDestinationSelected: _onSelectTab,
                                  labelType: NavigationRailLabelType.all,
                                  indicatorColor: NsColors.surfacePressed,
                                  destinations: _tabs.indexed.map((entry) {
                                    final (index, tab) = entry;
                                    return NavigationRailDestination(
                                      icon: NsIcon(
                                        tab.icon,
                                        size: 22,
                                        color: NsColors.textSecondary,
                                      ),
                                      selectedIcon: NsIcon(
                                        tab.icon,
                                        size: 22,
                                        color: NsColors.brandAction,
                                      ),
                                      label: Text(tab.label, key: guide.tabs[index]),
                                    );
                                  }).toList(),
                                ),
                                const VerticalDivider(width: 1),
                                Expanded(child: navigationShell),
                              ],
                            )
                          : navigationShell,
                    ),
                  ],
                ),
                bottomNavigationBar: isTablet
                    ? null
                    : Container(
                        decoration: const BoxDecoration(
                          color: NsColors.surfaceCanvas,
                          border: Border(
                            top: BorderSide(color: NsColors.borderDefault),
                          ),
                        ),
                        // Navigation labels stay legible in a compact five-tab
                        // bar; content retains the user's full text scale.
                        child: MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1.2,
                          child: NavigationBar(
                            height:
                                MediaQuery.textScalerOf(context).scale(1) > 1.3
                                    ? 76
                                    : 64,
                            backgroundColor: NsColors.surfaceCanvas,
                            surfaceTintColor: Colors.transparent,
                            indicatorColor: NsColors.surfacePressed,
                            selectedIndex: navigationShell.currentIndex,
                            onDestinationSelected: _onSelectTab,
                            destinations: _tabs.indexed.map((entry) {
                                    final (index, tab) = entry;
                              return NavigationDestination(
                                key: guide.tabs[index],
                                icon: NsIcon(
                                  tab.icon,
                                  size: 22,
                                  color: NsColors.textSecondary,
                                ),
                                selectedIcon: NsIcon(
                                  tab.icon,
                                  size: 22,
                                  color: NsColors.brandAction,
                                ),
                                label: tab.label,
                              );
                            }).toList(),
                          ),
                        ),
                      ),
              ),
            );
          },
        );
      },
      ),
    );
  }
}
