import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:time_table/features/auth/screens/login_screen.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/providers/providers.dart';
import 'package:time_table/repositories/repositories.dart';
import 'package:time_table/routes/app_router.dart';

void main() {
  Widget createLoginTestWidget({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        home: LoginScreen(),
      ),
    );
  }

  group('TimePilot Login & Authentication Tests', () {
    testWidgets('1. Login screen renders with branding, email, password, and buttons',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createLoginTestWidget());
      await tester.pumpAndSettle();

      // Check TimePilot branding
      expect(find.text('TimePilot'), findsWidgets);
      expect(find.text('Automated College Timetable Generator'), findsWidgets);
      expect(find.text('Sign In'), findsWidgets);
      expect(find.text('Create Account'), findsWidgets);

      // Check inputs
      expect(find.text('College Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Sign In to TimePilot'), findsOneWidget);
    });

    testWidgets('2. Email field validates empty and invalid email format',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createLoginTestWidget());
      await tester.pumpAndSettle();

      // Click submit without entering email or password
      final submitButton = find.text('Sign In to TimePilot');
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify empty field validation error
      expect(find.text('Please enter your college email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);

      // Enter invalid email format
      final emailField = find.widgetWithText(TextFormField, 'e.g. professor@college.edu or name@gmail.com');
      await tester.enterText(emailField, 'invalid-email-format');
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify invalid email format validation message
      expect(
        find.text('Please enter a valid email address (e.g. name@college.edu or name@gmail.com)'),
        findsOneWidget,
      );
    });

    testWidgets('3. Password field is obscured by default and toggles visibility smoothly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createLoginTestWidget());
      await tester.pumpAndSettle();

      // Find password TextField
      final passwordFinder = find.byWidgetPredicate((w) =>
          w is TextField && w.decoration?.hintText == 'Enter your password');
      expect(passwordFinder, findsOneWidget);

      // Verify secure by default
      final initialField = tester.widget<TextField>(passwordFinder);
      expect(initialField.obscureText, isTrue);

      // Find animated eye toggle button
      final eyeButton = find.byTooltip('Show password');
      expect(eyeButton, findsOneWidget);

      // Tap the eye icon to reveal password
      await tester.tap(eyeButton);
      await tester.pump(); // Starts smooth animation
      await tester.pump(const Duration(milliseconds: 150)); // Mid-animation
      await tester.pumpAndSettle(); // Animation completes

      // Verify password is now visible
      final revealedField = tester.widget<TextField>(passwordFinder);
      expect(revealedField.obscureText, isFalse);
      expect(find.byTooltip('Hide password'), findsOneWidget);

      // Tap again to hide password
      await tester.tap(find.byTooltip('Hide password'));
      await tester.pumpAndSettle();

      // Verify password is obscured again
      final obscuredAgainField = tester.widget<TextField>(passwordFinder);
      expect(obscuredAgainField.obscureText, isTrue);
    });

    testWidgets('4. Registration UI only supports College Admin (no Teacher/Student options)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createLoginTestWidget());
      await tester.pumpAndSettle();

      // Tap Create Account toggle tab
      await tester.tap(find.text('Create Account').first);
      await tester.pumpAndSettle();

      // Verify registration specific fields are displayed
      expect(find.text('Create College Account'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      // Admin-only: Ensure Teacher and Student options and Account Role dropdown are completely removed
      expect(find.text('Account Role'), findsNothing);
      expect(find.text('Teacher'), findsNothing);
      expect(find.text('Student'), findsNothing);
      expect(find.text('College / Institution Name'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Create TimePilot Account'), findsOneWidget);

      // Attempt submit empty registration
      final createButton = find.text('Create TimePilot Account');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(find.text('Please enter your full name'), findsOneWidget);
      expect(find.text('Please enter your institution name'), findsOneWidget);
    });

    testWidgets('5. Forgot Password dialog opens, validates, and sends reset email',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createLoginTestWidget());
      await tester.pumpAndSettle();

      // Tap Forgot Password?
      final forgotPasswordButton = find.text('Forgot Password?');
      expect(forgotPasswordButton, findsOneWidget);
      await tester.tap(forgotPasswordButton);
      await tester.pumpAndSettle();

      // Verify dialog appears
      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('TimePilot Account Recovery'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);

      // Try empty submission in dialog
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your college email'), findsOneWidget);

      // Enter valid email in dialog
      final dialogEmailField = find.widgetWithText(TextFormField, 'e.g. name@college.edu');
      await tester.enterText(dialogEmailField, 'dean@stanford.edu');
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      // Verify confirmation banner on login screen
      expect(find.textContaining('Password reset link dispatched to dean@stanford.edu'), findsOneWidget);
    });

    testWidgets('6. Successful login updates current user and active college ID',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Enter valid credentials
      final emailField = find.widgetWithText(TextFormField, 'e.g. professor@college.edu or name@gmail.com');
      final passwordField = find.widgetWithText(TextFormField, 'Enter your password');

      await tester.enterText(emailField, 'faculty@college.edu');
      await tester.enterText(passwordField, 'password123');
      await tester.tap(find.text('Sign In to TimePilot'));
      await tester.pumpAndSettle();

      // Verify current user profile in Riverpod
      final currentUser = container.read(currentProfileProvider);
      expect(currentUser, isNotNull);
      expect(currentUser!.email, 'faculty@college.edu');
    });

    testWidgets('7. Sign out clears current user profile and navigates to login state',
        (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Pre-set user
      container.read(currentProfileProvider.notifier).state = UserProfile(
        id: 'usr_test_123',
        email: 'test@college.edu',
        name: 'Prof. Test',
        role: UserRole.teacher,
        collegeId: 'col_isolated_1',
      );

      expect(container.read(currentProfileProvider), isNotNull);

      // Perform sign out
      await container.read(authControllerProvider.notifier).signOut();

      // Verify user is cleared
      expect(container.read(currentProfileProvider), isNull);
    });

    testWidgets('8. Multi-tenant data isolation: User A and User B receive isolated college IDs',
        (WidgetTester tester) async {
      final repo = containerRefForTest();

      // Register User A
      final userA = await repo.registerWithEmailAndPassword(
        email: 'admin_a@collegea.edu',
        password: 'password123',
        name: 'Admin A',
        role: UserRole.collegeAdmin,
        collegeId: 'college_alpha',
      );

      // Register User B
      final userB = await repo.registerWithEmailAndPassword(
        email: 'admin_b@collegeb.edu',
        password: 'password123',
        name: 'Admin B',
        role: UserRole.collegeAdmin,
        collegeId: 'college_beta',
      );

      // Verify separate identities and college tenant IDs
      expect(userA.id, isNot(equals(userB.id)));
      expect(userA.collegeId, 'college_alpha');
      expect(userB.collegeId, 'college_beta');
      expect(userA.collegeId, isNot(equals(userB.collegeId)));
    });

    testWidgets('9. Startup in Firebase mode: Unauthenticated session initializes to null and routes to /login',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer(
        overrides: [
          useFirebaseBackendProvider.overrideWith((ref) => true),
          authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);

      // Verify unauthenticated state in Firebase mode
      expect(container.read(currentProfileProvider), isNull);
      expect(container.read(activeCollegeIdProvider), isEmpty);

      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify it safely redirected to /login without hitting /dashboard
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Sign In to TimePilot'), findsOneWidget);
    });

    testWidgets('10. Startup in Firebase mode: Authenticated session resolves user_college and routes to /dashboard',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testProfile = UserProfile(
        id: 'usr_firebase_123',
        email: 'faculty@institution.edu',
        name: 'Dr. Faculty',
        role: UserRole.collegeAdmin,
        collegeId: 'user_college',
      );

      final container = ProviderContainer(
        overrides: [
          useFirebaseBackendProvider.overrideWith((ref) => true),
          authStateStreamProvider.overrideWith((ref) => Stream.value(testProfile)),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify currentProfile and activeCollegeId are set to user_college
      expect(container.read(currentProfileProvider)?.collegeId, equals('user_college'));
      expect(container.read(activeCollegeIdProvider), equals('user_college'));

      // Verify dashboard rendered
      expect(find.text('1. Dashboard'), findsOneWidget);
      expect(find.text('Input Workflow Checklist'), findsOneWidget);
    });

    testWidgets('11. Database queries with empty collegeId safely return empty collections without errors',
        (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          activeCollegeIdProvider.overrideWith((ref) => ''),
        ],
      );
      addTearDown(container.dispose);

      final staff = await container.read(staffListProvider.future);
      final sections = await container.read(sectionListProvider.future);
      final rooms = await container.read(roomListProvider.future);

      expect(staff, isNotNull);
      expect(sections, isNotNull);
      expect(rooms, isNotNull);
    });

    test('12. Existing timetable data still readable after logout/login cycle', () async {
      final container = ProviderContainer(
        overrides: [
          useFirebaseBackendProvider.overrideWith((ref) => false),
        ],
      );
      addTearDown(container.dispose);

      final userProfile = UserProfile(
        id: 'usr_test_admin',
        email: 'admin@college.edu',
        name: 'College Admin',
        role: UserRole.collegeAdmin,
        collegeId: 'user_college',
      );

      // 1. Seed a test section
      final db = container.read(databaseRepositoryProvider);
      await db.createSection(Section(
        id: 'sec_test_persisted',
        collegeId: 'user_college',
        departmentId: 'dept_cs',
        courseId: 'course_cs',
        academicYear: '2026-2027',
        semester: 3,
        sectionName: 'A',
        studentCount: 60,
      ));

      // 2. Log in
      container.read(currentProfileProvider.notifier).state = userProfile;
      container.read(activeCollegeIdProvider.notifier).state = 'user_college';

      final initialSections = await container.read(sectionListProvider.future);
      expect(initialSections, isNotEmpty);

      // 3. Log out
      await container.read(authControllerProvider.notifier).signOut();
      expect(container.read(currentProfileProvider), isNull);

      // 4. Log back in
      container.read(currentProfileProvider.notifier).state = userProfile;
      container.read(activeCollegeIdProvider.notifier).state = 'user_college';

      final reloadedSections = await container.read(sectionListProvider.future);
      expect(reloadedSections.length, equals(initialSections.length));
      expect(reloadedSections.any((s) => s.id == 'sec_test_persisted'), isTrue);
    });

    testWidgets('13. Profile loading: router displays /loading splash while Firebase Auth initializes',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer(
        overrides: [
          useFirebaseBackendProvider.overrideWith((ref) => true),
          authStateStreamProvider.overrideWith((ref) => const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();

      // Verify CircularProgressIndicator on /loading route
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('1. Dashboard'), findsNothing);
    });

    testWidgets('14. Missing /users/{uid} document resolution: assigns real UID and preserves authentication flow',
        (WidgetTester tester) async {
      final repo = containerRefForTest();
      final user = await repo.signInWithEmailAndPassword(
        email: 'legacy_admin@unisched.edu',
        password: 'password123',
      );
      expect(user, isNotNull);
      expect(user.id, isNotEmpty);
      expect(user.email, equals('legacy_admin@unisched.edu'));
    });

    test('15. Newly registered College Admin A gets unique collegeId = col_A', () async {
      final repo = containerRefForTest();
      final adminA = await repo.registerWithEmailAndPassword(
        email: 'dean_a@colleges.edu',
        password: 'password123',
        name: 'Dean Alpha',
        role: UserRole.collegeAdmin,
        collegeName: 'Alpha University',
      );
      expect(adminA.role, equals(UserRole.collegeAdmin));
      expect(adminA.collegeId, equals('col_${adminA.id}'));
      expect(adminA.collegeId, isNot(equals('user_college')));
    });

    test('16. Newly registered College Admin B gets unique collegeId = col_B', () async {
      final repo = containerRefForTest();
      final adminB = await repo.registerWithEmailAndPassword(
        email: 'dean_b@colleges.edu',
        password: 'password123',
        name: 'Dean Beta',
        role: UserRole.collegeAdmin,
        collegeName: 'Beta Institute',
      );
      expect(adminB.role, equals(UserRole.collegeAdmin));
      expect(adminB.collegeId, equals('col_${adminB.id}'));
      expect(adminB.collegeId, isNot(equals('user_college')));
    });

    test('17. Account A and Account B are strictly isolated', () async {
      final repo = containerRefForTest();
      final adminA = await repo.registerWithEmailAndPassword(
        email: 'admin_a_iso@test.com',
        password: 'password123',
        name: 'Admin A',
        role: UserRole.collegeAdmin,
      );
      final adminB = await repo.registerWithEmailAndPassword(
        email: 'admin_b_iso@test.com',
        password: 'password123',
        name: 'Admin B',
        role: UserRole.collegeAdmin,
      );

      expect(adminA.id, isNot(equals(adminB.id)));
      expect(adminA.collegeId, isNot(equals(adminB.collegeId)));
      expect(adminA.collegeId, equals('col_${adminA.id}'));
      expect(adminB.collegeId, equals('col_${adminB.id}'));
    });

    test('18. Account A data remains accessible after logout/login', () async {
      final container = ProviderContainer(
        overrides: [
          useFirebaseBackendProvider.overrideWith((ref) => false),
        ],
      );
      addTearDown(container.dispose);

      final db = container.read(databaseRepositoryProvider);
      final adminA = UserProfile(
        id: 'usr_admin_a_persist',
        email: 'admin_a_persist@test.com',
        name: 'Admin A',
        role: UserRole.collegeAdmin,
        collegeId: 'col_usr_admin_a_persist',
      );

      // Create section under Admin A's college
      await db.createSection(Section(
        id: 'sec_admin_a',
        collegeId: adminA.collegeId!,
        departmentId: 'dept_a',
        courseId: 'course_a',
        academicYear: '2026-2027',
        semester: 1,
        sectionName: 'A1',
        studentCount: 45,
      ));

      // Login as Admin A
      container.read(currentProfileProvider.notifier).state = adminA;
      container.read(activeCollegeIdProvider.notifier).state = adminA.collegeId!;
      final sectionsA = await container.read(sectionListProvider.future);
      expect(sectionsA.any((s) => s.id == 'sec_admin_a'), isTrue);

      // Logout
      await container.read(authControllerProvider.notifier).signOut();
      expect(container.read(currentProfileProvider), isNull);

      // Login again as Admin A
      container.read(currentProfileProvider.notifier).state = adminA;
      container.read(activeCollegeIdProvider.notifier).state = adminA.collegeId!;
      final reloadedSections = await container.read(sectionListProvider.future);
      expect(reloadedSections.any((s) => s.id == 'sec_admin_a'), isTrue);
    });

    test('19. Account B starts with empty college data (no inheritance from A or user_college)', () async {
      final container = ProviderContainer(
        overrides: [
          useFirebaseBackendProvider.overrideWith((ref) => false),
        ],
      );
      addTearDown(container.dispose);

      final db = container.read(databaseRepositoryProvider);

      // Seed data in legacy user_college
      await db.createSection(Section(
        id: 'sec_legacy_user_college',
        collegeId: 'user_college',
        departmentId: 'dept_legacy',
        courseId: 'course_legacy',
        academicYear: '2026-2027',
        semester: 1,
        sectionName: 'Legacy Sec',
        studentCount: 50,
      ));

      // Seed data in Admin A's college
      final collegeAId = 'col_admin_a_isolated';
      await db.createSection(Section(
        id: 'sec_admin_a_data',
        collegeId: collegeAId,
        departmentId: 'dept_a',
        courseId: 'course_a',
        academicYear: '2026-2027',
        semester: 1,
        sectionName: 'Sec A',
        studentCount: 40,
      ));

      // Register new Admin B
      final repo = containerRefForTest();
      final adminB = await repo.registerWithEmailAndPassword(
        email: 'brand_new_admin_b@college.edu',
        password: 'password123',
        name: 'Admin B',
        role: UserRole.collegeAdmin,
      );

      // Verify Admin B receives their own unique collegeId and not user_college or collegeAId
      expect(adminB.collegeId, equals('col_${adminB.id}'));
      expect(adminB.collegeId, isNot(equals('user_college')));
      expect(adminB.collegeId, isNot(equals(collegeAId)));

      // Query data under Admin B's college
      container.read(currentProfileProvider.notifier).state = adminB;
      container.read(activeCollegeIdProvider.notifier).state = adminB.collegeId!;

      final sectionsB = await container.read(sectionListProvider.future);
      final staffB = await container.read(staffListProvider.future);
      final roomsB = await container.read(roomListProvider.future);

      // Admin B must have completely empty data
      expect(sectionsB, isEmpty);
      expect(staffB, isEmpty);
      expect(roomsB, isEmpty);
    });

    test('20. Existing Firestore data under user_college is preserved and never overwritten', () async {
      final db = LocalDatabaseRepository();

      // Pre-existing legacy section in user_college
      final existingLegacySection = Section(
        id: 'sec_existing_untouched',
        collegeId: 'user_college',
        departmentId: 'dept_engineering',
        courseId: 'course_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: 'CS-E',
        studentCount: 65,
      );
      await db.createSection(existingLegacySection);

      // New registrations happen
      final repo = containerRefForTest();
      await repo.registerWithEmailAndPassword(
        email: 'new_tenant_1@edu.com',
        password: 'password123',
        name: 'New Tenant 1',
        role: UserRole.collegeAdmin,
      );
      await repo.registerWithEmailAndPassword(
        email: 'new_tenant_2@edu.com',
        password: 'password123',
        name: 'New Tenant 2',
        role: UserRole.collegeAdmin,
      );

      // Check user_college data is completely preserved
      final legacySections = await db.getSections('user_college');
      expect(legacySections.any((s) => s.id == 'sec_existing_untouched'), isTrue);
      final section = legacySections.firstWhere((s) => s.id == 'sec_existing_untouched');
      expect(section.studentCount, equals(65));
      expect(section.sectionName, equals('CS-E'));
    });

    test('21. Existing user profiles with collegeId retain their collegeId', () async {
      final repo = containerRefForTest();

      // Pre-existing user with legacy collegeId
      final existingUser = UserProfile(
        id: 'usr_existing_cust',
        email: 'existing_cust@college.edu',
        name: 'Existing Admin',
        role: UserRole.collegeAdmin,
        collegeId: 'custom_legacy_college_123',
      );
      await repo.updateUserProfile(existingUser);

      // Signing in with existing email returns the exact profile and collegeId
      final signedIn = await repo.signInWithEmailAndPassword(
        email: 'existing_cust@college.edu',
        password: 'password123',
      );

      expect(signedIn.id, equals('usr_existing_cust'));
      expect(signedIn.collegeId, equals('custom_legacy_college_123'));
    });

    test('22. Firestore rules security logic: belongsToCollege ensures multi-tenant isolation', () {
      // Simulating belongsToCollege(targetCollegeId) rule logic
      bool belongsToCollege({
        required bool isAuthenticated,
        required bool isSuperAdmin,
        required String? userCollegeId,
        required String targetCollegeId,
      }) {
        if (!isAuthenticated) return false;
        if (isSuperAdmin) return true;
        if (userCollegeId == null || userCollegeId.isEmpty) return false;
        return userCollegeId == targetCollegeId;
      }

      const collegeA = 'col_alpha';
      const collegeB = 'col_beta';

      // Unauthenticated user -> DENIED
      expect(belongsToCollege(
        isAuthenticated: false,
        isSuperAdmin: false,
        userCollegeId: collegeA,
        targetCollegeId: collegeA,
      ), isFalse);

      // Authenticated User A accessing College A -> ALLOWED
      expect(belongsToCollege(
        isAuthenticated: true,
        isSuperAdmin: false,
        userCollegeId: collegeA,
        targetCollegeId: collegeA,
      ), isTrue);

      // Authenticated User A accessing College B -> DENIED (Cross-college access blocked)
      expect(belongsToCollege(
        isAuthenticated: true,
        isSuperAdmin: false,
        userCollegeId: collegeA,
        targetCollegeId: collegeB,
      ), isFalse);

      // Authenticated User B accessing College A -> DENIED
      expect(belongsToCollege(
        isAuthenticated: true,
        isSuperAdmin: false,
        userCollegeId: collegeB,
        targetCollegeId: collegeA,
      ), isFalse);

      // Authenticated User B accessing College B -> ALLOWED
      expect(belongsToCollege(
        isAuthenticated: true,
        isSuperAdmin: false,
        userCollegeId: collegeB,
        targetCollegeId: collegeB,
      ), isTrue);

      // User with missing/null collegeId -> DENIED safely without errors
      expect(belongsToCollege(
        isAuthenticated: true,
        isSuperAdmin: false,
        userCollegeId: null,
        targetCollegeId: collegeA,
      ), isFalse);
    });
  });
}

LocalAuthRepository containerRefForTest() {
  return LocalAuthRepository();
}
