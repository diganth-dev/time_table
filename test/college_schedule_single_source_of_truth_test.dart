import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/features/staff/screens/staff_list_screen.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/providers/providers.dart';
import 'package:time_table/repositories/repositories.dart';

void main() {
  group('College Schedule Single Source of Truth Synchronization Tests', () {
    const testCollegeId = 'col_single_source';

    final testDepts = [
      Department(id: 'dept_cse', collegeId: testCollegeId, name: 'Computer Science', code: 'CSE'),
    ];

    testWidgets('Exact Scenario: College Schedule timings reflect live in Professor Availability From/To dropdowns after update', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = LocalDatabaseRepository();

      // Step 1: Open College Schedule and note the current period timings
      final initialSlots = [
        TimeSlot(id: 'ts_1', collegeId: testCollegeId, periodNumber: 1, startTime: '09:00', endTime: '10:00', order: 1),
        TimeSlot(id: 'ts_2', collegeId: testCollegeId, periodNumber: 2, startTime: '10:00', endTime: '11:00', order: 2),
        TimeSlot(id: 'ts_b1', collegeId: testCollegeId, periodNumber: 0, startTime: '11:00', endTime: '11:15', isBreak: true, breakTitle: 'Morning Break', order: 3),
        TimeSlot(id: 'ts_3', collegeId: testCollegeId, periodNumber: 3, startTime: '11:15', endTime: '12:15', order: 4),
        TimeSlot(id: 'ts_4', collegeId: testCollegeId, periodNumber: 4, startTime: '12:15', endTime: '13:15', order: 5),
        TimeSlot(id: 'ts_lunch', collegeId: testCollegeId, periodNumber: 0, startTime: '13:15', endTime: '14:00', isBreak: true, breakTitle: 'Lunch Break', order: 6),
        TimeSlot(id: 'ts_5', collegeId: testCollegeId, periodNumber: 5, startTime: '14:00', endTime: '15:00', order: 7),
        TimeSlot(id: 'ts_6', collegeId: testCollegeId, periodNumber: 6, startTime: '15:00', endTime: '16:00', order: 8),
      ];
      await repo.saveTimeSlots(testCollegeId, initialSlots);

      // Verify initial College Schedule timings in repository
      final notedInitialSlots = await repo.getTimeSlots(testCollegeId);
      expect(notedInitialSlots.first.startTime, '09:00');
      expect(notedInitialSlots.first.endTime, '10:00');

      // Build the app with Riverpod ProviderScope connected to this repository
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseRepositoryProvider.overrideWithValue(repo),
            activeCollegeIdProvider.overrideWith((ref) => testCollegeId),
            departmentListProvider.overrideWith((ref) => Future.value(testDepts)),
            staffListProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: StaffListScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 2: Open Add/Edit Professor → Professor Availability → From/To
      final addProfessorBtn = find.text('Add Professor');
      expect(addProfessorBtn, findsOneWidget);
      await tester.tap(addProfessorBtn);
      await tester.pumpAndSettle();

      // Step 3: Confirm the dropdown shows the current College Schedule timings
      expect(find.text('Professor Availability'), findsOneWidget);
      final fromDropdown = find.widgetWithText(DropdownButtonFormField<String>, 'From');
      expect(fromDropdown, findsOneWidget);

      await tester.tap(fromDropdown);
      await tester.pumpAndSettle();

      // Confirm initial timings: Period 1 starts at 9:00 AM
      expect(find.text('Period 1 — 9:00 AM'), findsWidgets);
      expect(find.text('Period 2 — 10:00 AM'), findsWidgets);
      expect(find.text('Morning Break — 11:00 AM'), findsWidgets);
      expect(find.text('Period 3 — 11:15 AM'), findsWidgets);
      expect(find.text('Period 6 End — 4:00 PM'), findsWidgets);

      // Select an item to close the dropdown menu cleanly
      await tester.tap(find.text('Period 1 — 9:00 AM').last);
      await tester.pumpAndSettle();

      // Close the dialog by tapping Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Professor Availability'), findsNothing);

      // Step 4 & 5: Change a College Schedule period time and Save
      // Change Period 1 from 09:00-10:00 to 08:30-09:30
      // Change Period 2 from 10:00-11:00 to 09:30-10:30
      final updatedSlots = [
        TimeSlot(id: 'ts_1', collegeId: testCollegeId, periodNumber: 1, startTime: '08:30', endTime: '09:30', order: 1),
        TimeSlot(id: 'ts_2', collegeId: testCollegeId, periodNumber: 2, startTime: '09:30', endTime: '10:30', order: 2),
        TimeSlot(id: 'ts_b1', collegeId: testCollegeId, periodNumber: 0, startTime: '10:30', endTime: '10:45', isBreak: true, breakTitle: 'Morning Break', order: 3),
        TimeSlot(id: 'ts_3', collegeId: testCollegeId, periodNumber: 3, startTime: '10:45', endTime: '11:45', order: 4),
        TimeSlot(id: 'ts_4', collegeId: testCollegeId, periodNumber: 4, startTime: '11:45', endTime: '12:45', order: 5),
        TimeSlot(id: 'ts_lunch', collegeId: testCollegeId, periodNumber: 0, startTime: '12:45', endTime: '13:30', isBreak: true, breakTitle: 'Lunch Break', order: 6),
        TimeSlot(id: 'ts_5', collegeId: testCollegeId, periodNumber: 5, startTime: '13:30', endTime: '14:30', order: 7),
        TimeSlot(id: 'ts_6', collegeId: testCollegeId, periodNumber: 6, startTime: '14:30', endTime: '15:30', order: 8),
      ];

      // Save the updated College Schedule to the single source of truth repository
      await repo.saveTimeSlots(testCollegeId, updatedSlots);

      // Trigger provider invalidation so the app reflects the saved schedule
      final element = tester.element(find.byType(StaffListScreen));
      final container = ProviderScope.containerOf(element);
      container.invalidate(timeSlotsProvider);
      await tester.pumpAndSettle();

      // Step 6: Reopen Add/Edit Professor → Professor Availability
      await tester.tap(addProfessorBtn);
      await tester.pumpAndSettle();

      expect(find.text('Professor Availability'), findsOneWidget);

      // Step 7: Confirm the From/To dropdown now shows the UPDATED College Schedule timing
      final updatedFromDropdown = find.widgetWithText(DropdownButtonFormField<String>, 'From');
      await tester.tap(updatedFromDropdown);
      await tester.pumpAndSettle();

      // Confirm NEW updated timing is present:
      expect(find.text('Period 1 — 8:30 AM'), findsWidgets);
      expect(find.text('Period 2 — 9:30 AM'), findsWidgets);
      expect(find.text('Morning Break — 10:30 AM'), findsWidgets);
      expect(find.text('Period 3 — 10:45 AM'), findsWidgets);
      expect(find.text('Period 6 End — 3:30 PM'), findsWidgets);

      // Confirm OLD timings no longer exist in the dropdown
      expect(find.text('Period 1 — 9:00 AM'), findsNothing);
      expect(find.text('Period 2 — 10:00 AM'), findsNothing);
      expect(find.text('Morning Break — 11:00 AM'), findsNothing);
      expect(find.text('Period 6 End — 4:00 PM'), findsNothing);

      // Select an item to close the dropdown menu cleanly
      await tester.tap(find.text('Period 1 — 8:30 AM').last);
      await tester.pumpAndSettle();

      // Close the dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Step 8: Confirm there is no hardcoded or duplicated schedule-time list
      // Test completely custom, non-standard timings (e.g. Evening College: 17:00 - 18:00, 18:00 - 19:00)
      final eveningSlots = [
        TimeSlot(id: 'ts_e1', collegeId: testCollegeId, periodNumber: 1, startTime: '17:00', endTime: '18:00', order: 1),
        TimeSlot(id: 'ts_e2', collegeId: testCollegeId, periodNumber: 2, startTime: '18:00', endTime: '19:00', order: 2),
      ];
      await repo.saveTimeSlots(testCollegeId, eveningSlots);
      container.invalidate(timeSlotsProvider);
      await tester.pumpAndSettle();

      await tester.tap(addProfessorBtn);
      await tester.pumpAndSettle();

      final eveningFromDropdown = find.widgetWithText(DropdownButtonFormField<String>, 'From');
      await tester.tap(eveningFromDropdown);
      await tester.pumpAndSettle();

      // Exactly the custom evening timings appear
      expect(find.text('Period 1 — 5:00 PM'), findsWidgets);
      expect(find.text('Period 2 — 6:00 PM'), findsWidgets);
      expect(find.text('Period 2 End — 7:00 PM'), findsWidgets);

      // None of the standard daytime timings appear
      expect(find.text('Period 1 — 8:30 AM'), findsNothing);
      expect(find.text('Period 1 — 9:00 AM'), findsNothing);

      // Close dropdown menu and dialog
      await tester.tap(find.text('Period 1 — 5:00 PM').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Also confirm empty schedule behavior: 0 hardcoded fallbacks
      await repo.saveTimeSlots(testCollegeId, []);
      container.invalidate(timeSlotsProvider);
      await tester.pumpAndSettle();

      await tester.tap(addProfessorBtn);
      await tester.pumpAndSettle();

      // Both dropdowns show "No schedule" and zero hardcoded time options
      expect(find.text('No schedule'), findsNWidgets(2));
      expect(find.text('Period 1 — 9:00 AM'), findsNothing);
      expect(find.text('Period 1 — 8:30 AM'), findsNothing);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });
}
