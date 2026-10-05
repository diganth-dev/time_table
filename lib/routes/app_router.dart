import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/classrooms/screens/classrooms_screen.dart';
import '../features/conflicts/screens/conflict_center_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/dashboard/screens/main_shell_screen.dart';
import '../features/sections/screens/sections_and_subjects_screen.dart';
import '../features/settings/screens/period_settings_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/staff/screens/staff_availability_screen.dart';
import '../features/staff/screens/staff_list_screen.dart';
import '../features/timetable/screens/export_screen.dart';
import '../features/timetable/screens/timetable_screen.dart';
import '../features/workflow/screens/input_workflow_screen.dart';
import '../models/models.dart';
import '../providers/providers.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<UserProfile?>(
      currentProfileProvider,
      (prev, next) => notifyListeners(),
    );

    // Sync Firebase auth state changes to currentProfileProvider and activeCollegeIdProvider
    _ref.listen<AsyncValue<UserProfile?>>(
      authStateStreamProvider,
      (prev, next) {
        if (next.hasValue) {
          final profile = next.value;
          _ref.read(currentProfileProvider.notifier).state = profile;
          if (profile?.collegeId != null && profile!.collegeId!.isNotEmpty) {
            _ref.read(activeCollegeIdProvider.notifier).state = profile.collegeId!;
          }
        }
        notifyListeners();
      },
    );
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: notifier,
    redirect: (context, state) {
      final useFirebase = ref.read(useFirebaseBackendProvider);
      final authAsync = ref.read(authStateStreamProvider);

      // In Firebase mode, hold routing until Firebase Auth has initialized initial session state
      if (useFirebase && authAsync.isLoading) {
        if (state.matchedLocation != '/loading') {
          return '/loading';
        }
        return null;
      }

      final user = ref.read(currentProfileProvider) ?? authAsync.valueOrNull;
      final isLoggingIn = state.matchedLocation == '/login';
      final isLoadingRoute = state.matchedLocation == '/loading';

      // If unauthenticated: redirect to /login
      if (user == null) {
        if (!isLoggingIn) return '/login';
        return null;
      }

      // If authenticated and currently on /login, /loading, or root: redirect to /dashboard
      if (isLoggingIn || isLoadingRoute || state.matchedLocation == '/') {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      // Top-level Loading / Splash Route while Firebase Auth initializes
      GoRoute(
        path: '/loading',
        builder: (context, state) => const Scaffold(
          backgroundColor: Color(0xFF0F172A),
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFF2563EB)),
          ),
        ),
      ),
      // Top-level Login Route outside MainShellScreen
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShellScreen(child: child),
        routes: [
          // 1. Dashboard
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),

          // 2. College Schedule (Working days, periods, timings, breaks)
          GoRoute(
            path: '/schedule',
            builder: (context, state) => const PeriodSettingsScreen(),
          ),
          GoRoute(
            path: '/settings/periods',
            builder: (context, state) => const PeriodSettingsScreen(),
          ),

          // 3. Professors (Names, subjects can teach, availability)
          GoRoute(
            path: '/professors',
            builder: (context, state) => const StaffListScreen(),
          ),
          GoRoute(
            path: '/staff',
            builder: (context, state) => const StaffListScreen(),
          ),
          GoRoute(
            path: '/staff/availability',
            builder: (context, state) => const StaffAvailabilityScreen(),
          ),

          // 4. Sections & Subjects (Sections A, B, C, assigned subjects, hours, theory/lab)
          GoRoute(
            path: '/sections-subjects',
            builder: (context, state) => const SectionsAndSubjectsScreen(),
          ),
          GoRoute(
            path: '/sections',
            builder: (context, state) => const SectionsAndSubjectsScreen(),
          ),
          GoRoute(
            path: '/subjects',
            builder: (context, state) => const SectionsAndSubjectsScreen(),
          ),

          // 5. Rooms & Labs (Room numbers, type, capacity)
          GoRoute(
            path: '/rooms',
            builder: (context, state) => const ClassroomsScreen(),
          ),
          GoRoute(
            path: '/classrooms',
            builder: (context, state) => const ClassroomsScreen(),
          ),

          // 6. Generate Timetable (6-step guided input workflow)
          GoRoute(
            path: '/workflow',
            builder: (context, state) => const InputWorkflowScreen(),
          ),
          GoRoute(
            path: '/timetable/generate',
            builder: (context, state) => const InputWorkflowScreen(),
          ),

          // 7. Timetable Matrix (Section, Professor, Room views + breaks)
          GoRoute(
            path: '/timetable',
            builder: (context, state) => const TimetableScreen(),
          ),

          // 8. Conflict Center (6-point verification checklist & diagnostic fixes)
          GoRoute(
            path: '/conflicts',
            builder: (context, state) => const ConflictCenterScreen(),
          ),

          // 9. Export (Print, CSV, PDF, JSON)
          GoRoute(
            path: '/export',
            builder: (context, state) => const ExportScreen(),
          ),

          // Settings
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
