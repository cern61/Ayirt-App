import 'package:go_router/go_router.dart';

import '../features/admin/admin_shell.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/business/business_history_screen.dart';
import '../features/business/business_shell.dart';
import '../features/customer/booking_screen.dart';
import '../features/customer/business_detail_screen.dart';
import '../features/customer/customer_shell.dart';
import '../features/customer/my_bookings_screen.dart';
import 'session_controller.dart';

GoRouter buildRouter(SessionController session) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: session, // giriş/çıkışta redirect tekrar çalışır
    redirect: (context, state) {
      final location = state.matchedLocation;
      final onAuthPage = location == '/login' || location == '/register';
      final profile = session.profile;

      // Giriş yapılmamış → sadece giriş/kayıt sayfaları
      if (profile == null) return onAuthPage ? null : '/login';

      // Giriş yapılmış → herkes SADECE kendi rolünün bölümüne girebilir
      final home = profile.role.homePath;
      if (onAuthPage || !location.startsWith(home)) return home;
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: '/customer',
        builder: (context, state) => const CustomerShell(),
        routes: [
          // /customer/business/<id>
          GoRoute(
            path: 'business/:id',
            builder: (context, state) => BusinessDetailScreen(businessId: state.pathParameters['id']!),
            routes: [
              // /customer/business/<id>/book
              GoRoute(
                path: 'book',
                builder: (context, state) => BookingScreen(businessId: state.pathParameters['id']!),
              ),
            ],
          ),
          // /customer/bookings
          GoRoute(path: 'bookings', builder: (context, state) => const MyBookingsScreen()),
        ],
      ),
      GoRoute(
        path: '/business',
        builder: (context, state) => const BusinessShell(),
        routes: [
          // /business/history
          GoRoute(path: 'history', builder: (context, state) => const BusinessHistoryScreen()),
        ],
      ),
      GoRoute(path: '/admin', builder: (context, state) => const AdminShell()),
    ],
  );
}
