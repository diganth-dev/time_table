import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/features/timetable/screens/timetable_screen.dart';
import 'package:time_table/features/timetable/screens/export_screen.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/providers/providers.dart';

void main() {
  group('Timetable Grid Display: Breaks & B1/B2 Lab Tests', () {
    const collegeId = 'test_college';
    final workingDays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
    ];

    final college = College(
      id: collegeId,
      name: 'Alpha Engineering College',
      code: 'AEC',
      academicYear: '2026-2027',
      currentSemester: 'Odd 2026',
      workingDays: workingDays,
      periodsPerDay: 5,
      periodDurationMinutes: 60,
      startTime: '09:00',
      endTime: '16:00',
    );

    final timeSlots = [
      TimeSlot(
        id: 'ts_1',
        collegeId: collegeId,
        periodNumber: 1,
        startTime: '09:00',
        endTime: '10:00',
        order: 1,
      ),
      TimeSlot(
        id: 'ts_2',
        collegeId: collegeId,
        periodNumber: 2,
        startTime: '10:00',
        endTime: '11:00',
        order: 2,
      ),
      TimeSlot(
        id: 'ts_tea',
        collegeId: collegeId,
        periodNumber: 0,
        startTime: '11:00',
        endTime: '11:15',
        isBreak: true,
        breakTitle: 'Tea Break',
        order: 3,
      ),
      TimeSlot(
        id: 'ts_3',
        collegeId: collegeId,
        periodNumber: 3,
        startTime: '11:15',
        endTime: '12:15',
        order: 4,
      ),
      TimeSlot(
        id: 'ts_lunch',
        collegeId: collegeId,
        periodNumber: 0,
        startTime: '12:15',
        endTime: '13:00',
        isBreak: true,
        breakTitle: 'Lunch Break',
        order: 5,
      ),
      TimeSlot(
        id: 'ts_4',
        collegeId: collegeId,
        periodNumber: 4,
        startTime: '13:00',
        endTime: '14:00',
        order: 6,
      ),
    ];

    final sectionA = Section(
      id: 'sec_a',
      collegeId: collegeId,
      departmentId: 'dept_cse',
      courseId: 'c_btech',
      academicYear: '2026-2027',
      semester: 3,
      sectionName: 'Section A',
      studentCount: 60,
      batches: ['B1', 'B2'],
    );

    final theorySub = Subject(
      id: 'sub_math',
      collegeId: collegeId,
      departmentId: 'dept_cse',
      courseId: 'c_btech',
      semester: 3,
      subjectCode: 'MTH301',
      subjectName: 'Discrete Mathematics',
      subjectType: 'Theory',
      hoursPerWeek: 4,
      requiredRoomType: 'Classroom',
      assignedTeacherIds: ['prof_sharma'],
    );

    final labSub = Subject(
      id: 'sub_lab',
      collegeId: collegeId,
      departmentId: 'dept_cse',
      courseId: 'c_btech',
      semester: 3,
      subjectCode: 'DVL',
      subjectName: 'Database & Visualization Lab',
      subjectType: 'Lab',
      hoursPerWeek: 2,
      requiredRoomType: 'Computer Lab',
      assignedTeacherIds: ['prof_kumar'],
    );

    final staff = [
      Staff(
        id: 'prof_sharma',
        collegeId: collegeId,
        employeeId: 'EMP101',
        name: 'Dr. Sharma',
        email: 'sharma@college.edu',
        departmentId: 'dept_cse',
        status: 'active',
        subjectsCanTeach: ['Discrete Mathematics'],
        maxClassesPerDay: 4,
      ),
      Staff(
        id: 'prof_kumar',
        collegeId: collegeId,
        employeeId: 'EMP102',
        name: 'Prof. Kumar',
        email: 'kumar@college.edu',
        departmentId: 'dept_cse',
        status: 'active',
        subjectsCanTeach: ['Database & Visualization Lab'],
        maxClassesPerDay: 4,
      ),
    ];

    final rooms = [
      Room(
        id: 'room_101',
        collegeId: collegeId,
        roomNumber: 'Room 101',
        capacity: 60,
        roomType: 'Classroom',
      ),
      Room(
        id: 'lab_1',
        collegeId: collegeId,
        roomNumber: 'Lab 1',
        capacity: 35,
        roomType: 'Computer Lab',
      ),
      Room(
        id: 'lab_2',
        collegeId: collegeId,
        roomNumber: 'Lab 2',
        capacity: 35,
        roomType: 'Computer Lab',
      ),
    ];

    final entries = [
      // Theory subject: Monday Period 1
      TimetableEntry(
        id: 'entry_th',
        collegeId: collegeId,
        versionId: 'v1',
        sectionId: sectionA.id,
        subjectId: theorySub.id,
        teacherId: 'prof_sharma',
        roomId: 'room_101',
        timeSlotId: 'ts_1',
        dayOfWeek: 'Monday',
        periodNumber: 1,
      ),
      // Lab subject: Monday Period 3 (simultaneous B1 and B2)
      TimetableEntry(
        id: 'entry_lab_b1',
        collegeId: collegeId,
        versionId: 'v1',
        sectionId: sectionA.id,
        subjectId: labSub.id,
        teacherId: 'prof_kumar',
        roomId: 'lab_1',
        timeSlotId: 'ts_3',
        dayOfWeek: 'Monday',
        periodNumber: 3,
        batch: 'B1',
      ),
      TimetableEntry(
        id: 'entry_lab_b2',
        collegeId: collegeId,
        versionId: 'v1',
        sectionId: sectionA.id,
        subjectId: labSub.id,
        teacherId: 'prof_kumar',
        roomId: 'lab_2',
        timeSlotId: 'ts_3',
        dayOfWeek: 'Monday',
        periodNumber: 3,
        batch: 'B2',
      ),
    ];

    testWidgets(
      'TimetableScreen renders merged Break and Lunch headers & titles',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentCollegeProvider.overrideWith(
                (ref) => Future.value(college),
              ),
              timeSlotsProvider.overrideWith((ref) => Future.value(timeSlots)),
              sectionListProvider.overrideWith(
                (ref) => Future.value([sectionA]),
              ),
              subjectListProvider.overrideWith(
                (ref) => Future.value([theorySub, labSub]),
              ),
              staffListProvider.overrideWith((ref) => Future.value(staff)),
              roomListProvider.overrideWith((ref) => Future.value(rooms)),
              timetableEntriesProvider.overrideWith(
                (ref) => Future.value(entries),
              ),
              timetableVersionsProvider.overrideWith(
                (ref) => Future.value(<TimetableVersion>[]),
              ),
              currentProfileProvider.overrideWith(
                (ref) => UserProfile(
                  id: 'admin_1',
                  email: 'admin@college.edu',
                  name: 'Admin',
                  role: UserRole.collegeAdmin,
                  collegeId: collegeId,
                  createdAt: DateTime.now(),
                ),
              ),
            ],
            child: const MaterialApp(home: Scaffold(body: TimetableScreen())),
          ),
        );

        await tester.pumpAndSettle();

        // Check break headers
        expect(find.text('Break'), findsAtLeastNWidgets(1));
        expect(find.text('Lunch'), findsAtLeastNWidgets(1));

        // Check break titles in merged continuous cells
        expect(find.text('Tea Break'), findsOneWidget);
        expect(find.text('Lunch Break'), findsOneWidget);

        // Verify academic periods
        expect(find.text('Period 1'), findsOneWidget);
        expect(find.text('Period 2'), findsOneWidget);
        expect(find.text('Period 3'), findsOneWidget);
        expect(find.text('Period 4'), findsOneWidget);
      },
    );

    testWidgets('TimetableScreen renders B1 and B2 simultaneous lab layout', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentCollegeProvider.overrideWith((ref) => Future.value(college)),
            timeSlotsProvider.overrideWith((ref) => Future.value(timeSlots)),
            sectionListProvider.overrideWith((ref) => Future.value([sectionA])),
            subjectListProvider.overrideWith(
              (ref) => Future.value([theorySub, labSub]),
            ),
            staffListProvider.overrideWith((ref) => Future.value(staff)),
            roomListProvider.overrideWith((ref) => Future.value(rooms)),
            timetableEntriesProvider.overrideWith(
              (ref) => Future.value(entries),
            ),
            timetableVersionsProvider.overrideWith(
              (ref) => Future.value(<TimetableVersion>[]),
            ),
            currentProfileProvider.overrideWith(
              (ref) => UserProfile(
                id: 'admin_1',
                email: 'admin@college.edu',
                name: 'Admin',
                role: UserRole.collegeAdmin,
                collegeId: collegeId,
                createdAt: DateTime.now(),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: TimetableScreen())),
        ),
      );

      await tester.pumpAndSettle();

      // B1 and B2 batches must both be displayed
      expect(find.text('B1'), findsOneWidget);
      expect(find.text('B2'), findsOneWidget);

      // Both suitable labs must be rendered for B1 and B2
      expect(find.text('Lab 1'), findsOneWidget);
      expect(find.text('Lab 2'), findsOneWidget);

      // Course short name DVL rendered in matrix and Course/Faculty/Venue table
      expect(find.text('DVL'), findsAtLeastNWidgets(2));

      // Simultaneous indicator rendered
      expect(find.text('and simultaneously:'), findsOneWidget);

      // Normal theory subject rendered without B1/B2
      expect(find.text('MTH301'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Room 101'), findsAtLeastNWidgets(1));

      // Section identifier banner
      expect(find.text('Section: Section A'), findsOneWidget);
      expect(find.text('Semester: 3'), findsOneWidget);

      // From & To Time rows
      expect(find.text('From'), findsAtLeastNWidgets(1));
      expect(find.text('To'), findsAtLeastNWidgets(1));

      // Course / Faculty / Venue Information Table
      expect(find.text('Course / Faculty / Venue Information'), findsOneWidget);
      expect(find.text('Course Code'), findsOneWidget);
      expect(find.text('Course Short Name'), findsOneWidget);
      expect(find.text('Course Name'), findsOneWidget);
      expect(find.text('Faculty'), findsOneWidget);
      expect(find.text('Venue'), findsOneWidget);
      expect(find.text('B1: Lab 1, B2: Lab 2'), findsOneWidget);
      expect(find.text('Dr. Sharma'), findsOneWidget);
      expect(find.text('Prof. Kumar'), findsAtLeastNWidgets(3));
    });

    testWidgets(
      'ExportScreen print view renders merged breaks and B1/B2 lab entries',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentCollegeProvider.overrideWith(
                (ref) => Future.value(college),
              ),
              timeSlotsProvider.overrideWith((ref) => Future.value(timeSlots)),
              sectionListProvider.overrideWith(
                (ref) => Future.value([sectionA]),
              ),
              subjectListProvider.overrideWith(
                (ref) => Future.value([theorySub, labSub]),
              ),
              staffListProvider.overrideWith((ref) => Future.value(staff)),
              roomListProvider.overrideWith((ref) => Future.value(rooms)),
              timetableEntriesProvider.overrideWith(
                (ref) => Future.value(entries),
              ),
              timetableVersionsProvider.overrideWith(
                (ref) => Future.value(<TimetableVersion>[]),
              ),
              currentProfileProvider.overrideWith(
                (ref) => UserProfile(
                  id: 'admin_1',
                  email: 'admin@college.edu',
                  name: 'Admin',
                  role: UserRole.collegeAdmin,
                  collegeId: collegeId,
                  createdAt: DateTime.now(),
                ),
              ),
            ],
            child: const MaterialApp(home: Scaffold(body: ExportScreen())),
          ),
        );

        await tester.pumpAndSettle();

        // Check Break & Lunch in export screen
        expect(find.text('Break'), findsAtLeastNWidgets(1));
        expect(find.text('Lunch'), findsAtLeastNWidgets(1));
        expect(find.text('Tea Break'), findsOneWidget);
        expect(find.text('Lunch Break'), findsOneWidget);

        // Check B1 & B2 in export screen
        expect(find.text('B1'), findsOneWidget);
        expect(find.text('B2'), findsOneWidget);
        expect(find.text('Lab 1'), findsOneWidget);
        expect(find.text('Lab 2'), findsOneWidget);
        expect(find.text('and simultaneously:'), findsOneWidget);

        // Section-specific header
        expect(
          find.textContaining('Section: Section A • Semester: 3'),
          findsOneWidget,
        );

        // From & To Time rows
        expect(find.text('From'), findsAtLeastNWidgets(1));
        expect(find.text('To'), findsAtLeastNWidgets(1));

        // Course / Faculty / Venue Information Table in export
        expect(
          find.text('Course / Faculty / Venue Information'),
          findsOneWidget,
        );
        expect(find.text('B1: Lab 1, B2: Lab 2'), findsOneWidget);
      },
    );
  });
}
