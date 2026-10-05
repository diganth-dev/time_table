import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/providers/providers.dart';
import 'package:time_table/repositories/repositories.dart';
import 'package:time_table/services/services.dart';

void main() {
  group('Single Class / Section Timetable Generation Tests', () {
    const collegeId = 'test_college';

    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

    final timeSlots = [
      TimeSlot(id: 'ts_1', collegeId: collegeId, periodNumber: 1, startTime: '09:00', endTime: '10:00', order: 1),
      TimeSlot(id: 'ts_2', collegeId: collegeId, periodNumber: 2, startTime: '10:00', endTime: '11:00', order: 2),
      TimeSlot(id: 'ts_break', collegeId: collegeId, periodNumber: 0, startTime: '11:00', endTime: '11:15', order: 3, isBreak: true),
      TimeSlot(id: 'ts_3', collegeId: collegeId, periodNumber: 3, startTime: '11:15', endTime: '12:15', order: 4),
      TimeSlot(id: 'ts_4', collegeId: collegeId, periodNumber: 4, startTime: '12:15', endTime: '13:15', order: 5),
    ];

    final rooms = [
      Room(id: 'r_101', collegeId: collegeId, roomNumber: 'Room 101', building: 'Academic', floor: 1, capacity: 50, roomType: 'Classroom'),
      Room(id: 'r_102', collegeId: collegeId, roomNumber: 'Room 102', building: 'Academic', floor: 1, capacity: 50, roomType: 'Classroom'),
    ];

    final professors = [
      Staff(
        id: 'prof_ravi',
        employeeId: 'EMP001',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        name: 'Dr. Ravi',
        email: 'ravi@college.edu',
        designation: 'Associate Professor',
        role: 'faculty',
        status: 'active',
        subjectsCanTeach: ['sub_dbms'],
        maxClassesPerDay: 4,
        maxClassesPerWeek: 20,
      ),
      Staff(
        id: 'prof_priya',
        employeeId: 'EMP002',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        name: 'Prof. Priya',
        email: 'priya@college.edu',
        designation: 'Assistant Professor',
        role: 'faculty',
        status: 'active',
        subjectsCanTeach: ['sub_os'],
        maxClassesPerDay: 4,
        maxClassesPerWeek: 20,
      ),
    ];

    final secA = Section(
      id: 'sec_a',
      collegeId: collegeId,
      departmentId: 'dept_cse',
      courseId: 'course_cse',
      academicYear: '2026-2027',
      semester: 3,
      sectionName: 'A',
      studentCount: 35,
    );

    final secB = Section(
      id: 'sec_b',
      collegeId: collegeId,
      departmentId: 'dept_cse',
      courseId: 'course_cse',
      academicYear: '2026-2027',
      semester: 3,
      sectionName: 'B',
      studentCount: 35,
    );

    final List<Subject> subjects = [
      Subject(
        id: 'sub_dbms_a',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'course_cse',
        sectionId: 'sec_a',
        semester: 3,
        subjectName: 'DBMS Sec A',
        subjectCode: 'sub_dbms',
        hoursPerWeek: 3,
        assignedTeacherIds: ['prof_ravi'],
      ),
      Subject(
        id: 'sub_os_a',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'course_cse',
        sectionId: 'sec_a',
        semester: 3,
        subjectName: 'OS Sec A',
        subjectCode: 'sub_os',
        hoursPerWeek: 3,
        assignedTeacherIds: ['prof_priya'],
      ),
      Subject(
        id: 'sub_dbms_b',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'course_cse',
        sectionId: 'sec_b',
        semester: 3,
        subjectName: 'DBMS Sec B',
        subjectCode: 'sub_dbms',
        hoursPerWeek: 3,
        assignedTeacherIds: ['prof_ravi'],
      ),
      Subject(
        id: 'sub_os_b',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'course_cse',
        sectionId: 'sec_b',
        semester: 3,
        subjectName: 'OS Sec B',
        subjectCode: 'sub_os',
        hoursPerWeek: 3,
        assignedTeacherIds: ['prof_priya'],
      ),
    ];

    test('1. Generates timetable for one selected class/section at a time', () {
      final resA = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [secA, secB],
        subjects: subjects,
        staffList: professors,
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: days,
        targetSectionId: secA.id,
      );

      expect(resA.isSuccess, isTrue);
      expect(resA.targetSectionId, equals(secA.id));
      expect(resA.sectionsScheduled, equals(1));
      expect(resA.totalClassesScheduled, equals(6)); // 3 hrs DBMS + 3 hrs OS
      expect(resA.newlyScheduledEntries.every((e) => e.sectionId == secA.id), isTrue);
      expect(resA.conflicts, isEmpty);
    });

    test('2. Missing teacher in Section B does not prevent generating Section A', () {
      // Create a broken subject for Section B with no assigned teacher
      final brokenSubjB = Subject(
        id: 'sub_broken_b',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'course_cse',
        sectionId: 'sec_b',
        semester: 3,
        subjectName: 'Broken Subject',
        subjectCode: 'CS399',
        hoursPerWeek: 4,
        assignedTeacherIds: [], // Missing teacher!
      );

      final List<Subject> mixedSubjects = [...subjects, brokenSubjB];

      // Global generation fails because of Section B
      final resGlobal = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [secA, secB],
        subjects: mixedSubjects,
        staffList: professors,
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: days,
      );
      expect(resGlobal.isSuccess, isFalse);

      // But single-section generation for Section A succeeds cleanly!
      final resA = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [secA, secB],
        subjects: mixedSubjects,
        staffList: professors,
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: days,
        targetSectionId: secA.id,
      );
      expect(resA.isSuccess, isTrue);
      expect(resA.totalClassesScheduled, equals(6));
      expect(resA.newlyScheduledEntries.every((e) => e.sectionId == secA.id), isTrue);
    });

    test('3. Multi-section sequential generation avoids teacher and room collisions', () {
      // First, generate Section A
      final resA = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [secA, secB],
        subjects: subjects,
        staffList: professors,
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: days,
        targetSectionId: secA.id,
      );
      expect(resA.isSuccess, isTrue);

      // Next, generate Section B providing Section A entries as existingEntries
      final resB = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [secA, secB],
        subjects: subjects,
        staffList: professors,
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: days,
        targetSectionId: secB.id,
        existingEntries: resA.entries,
      );
      expect(resB.isSuccess, isTrue);
      expect(resB.targetSectionId, equals(secB.id));
      expect(resB.newlyScheduledEntries.length, equals(6));
      expect(resB.newlyScheduledEntries.every((e) => e.sectionId == secB.id), isTrue);

      // Total entries should include both Section A and Section B
      expect(resB.entries.length, equals(12));

      // Validate that there are 0 teacher or room double-bookings between Section A and Section B
      final validation = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: resB.entries,
        sections: [secA, secB],
        subjects: subjects,
        staffList: professors,
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
      );
      expect(validation.isValid, isTrue);
      expect(validation.hardConflicts, isEmpty);
    });

    test('4. Regenerating Section A preserves Section B and updates cleanly', () {
      // Generate Section A
      final resA = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [secA, secB],
        subjects: subjects,
        staffList: professors,
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: days,
        targetSectionId: secA.id,
      );

      // Generate Section B
      final resB = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [secA, secB],
        subjects: subjects,
        staffList: professors,
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: days,
        targetSectionId: secB.id,
        existingEntries: resA.entries,
      );

      // Regenerate Section A with combined entries
      final resARegenerated = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [secA, secB],
        subjects: subjects,
        staffList: professors,
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: days,
        targetSectionId: secA.id,
        existingEntries: resB.entries,
      );

      expect(resARegenerated.isSuccess, isTrue);
      expect(resARegenerated.entries.length, equals(12));
      expect(resARegenerated.entries.where((e) => e.sectionId == secB.id).length, equals(6));
      expect(resARegenerated.entries.where((e) => e.sectionId == secA.id).length, equals(6));
    });

    test('5. Riverpod TimetableController generates and saves for single selected section', () async {
      final repo = LocalDatabaseRepository();
      final container = ProviderContainer(
        overrides: [
          databaseRepositoryProvider.overrideWithValue(repo),
          activeCollegeIdProvider.overrideWith((ref) => collegeId),
        ],
      );

      // Pre-seed data
      await repo.createCollege(College(id: collegeId, name: 'Apex Institute', code: 'APEX', workingDays: days, currentSemester: 'Odd 2026'));
      await repo.createSection(secA);
      await repo.createSection(secB);
      for (final s in subjects) {
        await repo.createSubject(s);
      }
      for (final p in professors) {
        await repo.createStaff(p);
      }
      for (final r in rooms) {
        await repo.createRoom(r);
      }
      await repo.saveTimeSlots(collegeId, timeSlots);

      // Generate specifically for secA
      final controller = container.read(timetableControllerProvider.notifier);
      final genResult = await controller.generateSchedule(targetSectionId: secA.id);

      expect(genResult.isSuccess, isTrue);
      expect(genResult.targetSectionId, equals(secA.id));
      expect(container.read(selectedSectionFilterProvider), equals(secA.id));

      final savedEntries = await repo.getTimetableEntries(collegeId, versionId: genResult.versionId);
      expect(savedEntries.length, equals(6));
      expect(savedEntries.every((e) => e.sectionId == secA.id), isTrue);

      container.dispose();
    });
  });
}
