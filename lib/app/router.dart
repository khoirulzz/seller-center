import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../ui/features/analytics/analytics_screen.dart';
import '../ui/features/auth/auth_screens.dart';
import '../ui/features/home/home_screen.dart';
import '../ui/features/orders/orders_screens.dart';
import '../ui/features/products/products_screens.dart';
import '../ui/features/shell/seller_app_shell.dart';
import '../ui/features/store_hub/store_hub_screens.dart';
import '../ui/features/stores/store_screens.dart';
import '../ui/state/seller_app_state.dart';

/// Konfigurasi `GoRouter` dengan `StatefulShellRoute.indexedStack` 5 tab tetap
/// dan redirect guard sesuai status sesi (`flutter-setup-declarative-routing.md` & `PRD` Bab 6.3).
GoRouter createSellerRouter(SellerAppState appState) {
  return GoRouter(
    initialLocation: '/launch',
    refreshListenable: appState,
    redirect: (BuildContext context, GoRouterState state) {
      final lifecycle = appState.lifecycle;
      final path = state.uri.path;
      final isAuthRoute = path == '/login' ||
          path == '/register' ||
          path == '/forgot-password';

      if (lifecycle == AuthLifecycleState.initializing) {
        return path == '/launch' ? null : '/launch';
      }
      if (lifecycle == AuthLifecycleState.unauthenticated) {
        return isAuthRoute ? null : '/login';
      }
      if (lifecycle == AuthLifecycleState.unverifiedEmail) {
        return path == '/verify' ? null : '/verify';
      }
      if (lifecycle == AuthLifecycleState.needsStoreOnboarding) {
        return path == '/stores/create' ? null : '/stores/create';
      }
      if (lifecycle == AuthLifecycleState.authenticatedReady) {
        if (path == '/launch' || isAuthRoute || path == '/verify') {
          return '/beranda';
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/launch',
        builder: (context, state) => SplashSessionScreen(appState: appState),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginRegisterScreen(
          appState: appState,
          isRegister: false,
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => LoginRegisterScreen(
          appState: appState,
          isRegister: true,
        ),
      ),
      GoRoute(
        path: '/verify',
        builder: (context, state) => VerifyEmailScreen(appState: appState),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => ForgotPasswordScreen(appState: appState),
      ),
      GoRoute(
        path: '/stores/create',
        builder: (context, state) =>
            CreateStoreWizardScreen(appState: appState),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => NotificationsScreen(appState: appState),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return SellerAppShell(
            navigationShell: navigationShell,
            appState: appState,
          );
        },
        branches: [
          // Tab 1: Beranda
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/beranda',
                builder: (context, state) => HomeScreen(appState: appState),
              ),
            ],
          ),
          // Tab 2: Pesanan
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pesanan',
                builder: (context, state) =>
                    OrdersListScreen(appState: appState),
                routes: [
                  GoRoute(
                    path: ':orderId',
                    builder: (context, state) => OrderDetailScreen(
                      appState: appState,
                      orderId: state.pathParameters['orderId'] ?? '',
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Tab 3: Produk & Stok
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/produk',
                builder: (context, state) => ProductsAndInventoryScreen(
                  appState: appState,
                  initialSubTab:
                      state.uri.queryParameters['tab'] ?? 'catalog',
                ),
                routes: [
                  GoRoute(
                    path: 'editor',
                    builder: (context, state) => ProductEditorScreen(
                      appState: appState,
                      productId: state.uri.queryParameters['id'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Tab 4: Analitik
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/analitik',
                builder: (context, state) =>
                    AnalyticsScreen(appState: appState),
              ),
            ],
          ),
          // Tab 5: Toko
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/toko',
                builder: (context, state) => StoreHubScreen(appState: appState),
                routes: [
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) =>
                        StoreSettingsScreen(appState: appState),
                  ),
                  GoRoute(
                    path: 'readiness',
                    builder: (context, state) =>
                        StoreReadinessScreen(appState: appState),
                  ),
                  GoRoute(
                    path: 'customers',
                    builder: (context, state) =>
                        CustomersScreen(appState: appState),
                  ),
                  GoRoute(
                    path: 'billing',
                    builder: (context, state) =>
                        BillingScreen(appState: appState),
                  ),
                  GoRoute(
                    path: 'account',
                    builder: (context, state) =>
                        AccountSecurityScreen(appState: appState),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
