import 'package:go_router/go_router.dart';

import 'screens/auth/auth_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/customer/customer_dashboard.dart';
import 'screens/customer/customer_main_screen.dart';
import 'screens/customer/subscription_screen.dart';
import 'screens/customer/pause_meal_screen.dart';
import 'screens/customer/transaction_screen.dart';
import 'screens/admin/admin_dispatch_screen.dart';
import 'screens/admin/admin_enquiries_screen.dart';
import 'screens/admin/admin_onboarding_screen.dart';
import 'screens/admin/admin_customer_management_screen.dart';
import 'screens/admin/admin_customer_detail_screen.dart';
import 'screens/admin/admin_analytics_screen.dart';
import 'screens/admin/admin_transactions_screen.dart';
import 'screens/admin/admin_settings_screen.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/splash_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => AdminShell(child: child),
      routes: [
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminDashboard(),
        ),
        GoRoute(
          path: '/admin/dispatch',
          builder: (context, state) => const AdminDispatchScreen(),
        ),
        GoRoute(
          path: '/admin/enquiries',
          builder: (context, state) => const AdminEnquiriesScreen(),
        ),
        GoRoute(
          path: '/admin/onboarding',
          builder: (context, state) => const AdminOnboardingScreen(),
        ),
        GoRoute(
          path: '/admin/customers',
          builder: (context, state) => const AdminCustomerManagementScreen(),
        ),
        GoRoute(
          path: '/admin/customer-details',
          builder: (context, state) {
            final customerId = state.extra as String;
            return AdminCustomerDetailScreen(customerId: customerId);
          },
        ),
        GoRoute(
          path: '/admin/settings',
          builder: (context, state) => const AdminSettingsScreen(),
        ),
        GoRoute(
          path: '/admin/analytics',
          builder: (context, state) => const AdminAnalyticsScreen(),
        ),
        GoRoute(
          path: '/admin/transactions',
          builder: (context, state) => const AdminTransactionsScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/customer',
      builder: (context, state) => const CustomerMainScreen(),
    ),
    GoRoute(
      path: '/subscribe',
      builder: (context, state) => const SubscriptionScreen(),
    ),
    GoRoute(
      path: '/pause-meal',
      builder: (context, state) => const CustomerPauseMealScreen(),
    ),
    GoRoute(
      path: '/transactions',
      builder: (context, state) => const CustomerTransactionScreen(),
    ),
  ],
  redirect: (context, state) {
    // Add logic here based on AuthProvider 
    // This is simple implementation. 
    // In production, sync auth state effectively.
    return null;
  },
);
