import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/motion/ns_haptics.dart';
import '../../../core/theme/ns_colors.dart';
import '../../../core/widgets/ns_widgets.dart';
import '../../../core/widgets/ns_root_back_guard.dart';
import '../../state/seller_app_state.dart';
import '../onboarding/seller_feature_guide.dart';
import '../updates/app_update_screen.dart';
import '../engagement/engagement_screens.dart';
import 'seller_top_bar.dart';

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
    return NotificationPoller(
      appState: appState,
      child: SellerFeatureGuide(
        userId: appState.user?.id,
        eligible: appState.lifecycle == AuthLifecycleState.authenticatedReady &&
            appState.activeStore != null &&
            const [
              '/beranda',
              '/pesanan',
              '/produk',
              '/analitik',
              '/toko',
            ].contains(location),
        showAnalytics: appState.activeRole.canViewCustomersAndAnalytics,
        builder: (context, guide) => ListenableBuilder(
          listenable: appState,
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 600;
                return NsRootBackGuard(
                  isHome: navigationShell.currentIndex == 0,
                  goHome: () => navigationShell.goBranch(0),
                  child: Scaffold(
                    appBar: SellerTopBar(
                      appState: appState,
                      storeTargetKey: guide.store,
                      availableWidth: constraints.maxWidth,
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
                                      selectedIndex:
                                          navigationShell.currentIndex,
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
                                          label: Text(
                                            tab.label,
                                            key: guide.tabs[index],
                                          ),
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
                                    MediaQuery.textScalerOf(context).scale(1) >
                                            1.3
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
      ),
    );
  }
}
