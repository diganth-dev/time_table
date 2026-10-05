import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/repositories/repositories.dart';
import 'package:time_table/services/services.dart';

void main() {
  test(
    'Scenario 28: 5 departments, 20 sections, 100 teachers, 90 rooms, 500 classes generation',
    () async {
      final db = LocalDatabaseRepository();
      const collegeId = 'col_scenario_28';

      // 1. Seed full scenario data
      await db.seedLargeScenario(collegeId);

      final departments = await db.getDepartments(collegeId);
      final sections = (await db.getSections(
        collegeId,
      )).map((section) => section.copyWith(batches: ['B1'])).toList();
      final staffList = await db.getStaffList(collegeId);
      final rooms = await db.getRooms(collegeId);
      final subjects = await db.getSubjects(collegeId);

      // Verify dataset counts meet specification
      expect(departments.length, equals(5));
      expect(sections.length, equals(20));
      expect(staffList.length, equals(100));
      expect(rooms.length, equals(90)); // 80 classrooms + 10 laboratories
      expect(
        subjects.length,
        equals(50),
      ); // 5 per semester x 2 semesters x 5 departments

      // 2. Configure academic periods (6 periods per day + breaks)
      final timeSlots = await db.getTimeSlots(collegeId);

      // 3. Execute constraint satisfaction generation engine
      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: sections,
        subjects: subjects,
        staffList: staffList,
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
      );

      // 4. Verify scheduling success
      if (!result.isSuccess) {
        for (final c in result.conflicts) {
          // ignore: avoid_print
          print('Scenario conflict: ${c.title} - ${c.description}');
        }
      }
      expect(result.isSuccess, isTrue);
      expect(result.sectionsScheduled, equals(20));
      expect(result.totalClassesScheduled, greaterThan(300));
      expect(result.conflicts.where((c) => c.isHard).isEmpty, isTrue);

      // 5. Verify hard constraints across generated entries
      final validation = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: result.entries,
        sections: sections,
        subjects: subjects,
        staffList: staffList,
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
      );

      expect(validation.isValid, isTrue);
      expect(validation.hardConflicts, isEmpty);
    },
  );
}
