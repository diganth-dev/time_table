import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/services/services.dart';

void main() {
  group('Backtracking Engine, CSP & Structured Conflict Diagnostics Tests', () {
    const collegeId = 'test_college';
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

    final academicTimeSlots = [
      TimeSlot(id: 'ts_1', collegeId: collegeId, periodNumber: 1, startTime: '08:50', endTime: '09:50', order: 1),
      TimeSlot(id: 'ts_2', collegeId: collegeId, periodNumber: 2, startTime: '09:50', endTime: '10:50', order: 2),
      TimeSlot(id: 'ts_b1', collegeId: collegeId, periodNumber: 0, startTime: '10:50', endTime: '11:10', order: 3, isBreak: true, breakTitle: 'Morning Break'),
      TimeSlot(id: 'ts_3', collegeId: collegeId, periodNumber: 3, startTime: '11:10', endTime: '12:10', order: 4),
      TimeSlot(id: 'ts_4', collegeId: collegeId, periodNumber: 4, startTime: '12:10', endTime: '13:10', order: 5),
      TimeSlot(id: 'ts_lunch', collegeId: collegeId, periodNumber: 0, startTime: '13:10', endTime: '14:45', order: 6, isBreak: true, breakTitle: 'Lunch Break'),
      TimeSlot(id: 'ts_5', collegeId: collegeId, periodNumber: 5, startTime: '14:45', endTime: '15:45', order: 7),
    ];

    final room103 = Room(
      id: 'room_103',
      collegeId: collegeId,
      roomNumber: '103',
      capacity: 90,
      roomType: 'Classroom',
    );
    final room105 = Room(
      id: 'room_105',
      collegeId: collegeId,
      roomNumber: '105',
      capacity: 30,
      roomType: 'Computer Lab',
    );

    final secAiml = Section(
      id: 'sec_aiml',
      collegeId: collegeId,
      departmentId: 'dept_cse',
      courseId: 'course_cse',
      academicYear: '2026-2027',
      semester: 5,
      sectionName: 'CSE(AIML)',
      studentCount: 57,
    );

    test('TASK 2, 4, 5, 8: Exact user scenario schedules all 5 TOC sessions and all 24 total hours with zero conflicts', () {
      final staffList = [
        Staff(
          id: 'staff_amresh',
          collegeId: collegeId,
          employeeId: '07',
          name: 'Amresh kumar',
          email: 'amresh@gmail.com',
          departmentId: '',
          subjectsCanTeach: ['E-waste'],
          maxClassesPerDay: 4,
          maxClassesPerWeek: 20,
          unavailableTimes: [
            UnavailableTime(dayOfWeek: 'Monday', startTime: '8:50', endTime: '09:50'),
          ],
        ),
        Staff(
          id: 'staff_kumar',
          collegeId: collegeId,
          employeeId: '01',
          name: 'Mr Kumarswamy',
          email: 'kumarswamy@gmail.com',
          departmentId: '',
          subjectsCanTeach: ['SEPM'],
          maxClassesPerDay: 4,
          maxClassesPerWeek: 20,
          unavailableTimes: [
            UnavailableTime(dayOfWeek: 'Monday', startTime: '9:00', endTime: '10:00'),
            UnavailableTime(dayOfWeek: 'Tuesday', startTime: '10:00', endTime: '11:00'),
            UnavailableTime(dayOfWeek: 'Wednesday', startTime: '11:15', endTime: '12:15'),
            UnavailableTime(dayOfWeek: 'Wednesday', startTime: '2:00', endTime: '3:00'),
            UnavailableTime(dayOfWeek: 'Thursday', startTime: '3:00', endTime: '4:00'),
            UnavailableTime(dayOfWeek: 'Friday', startTime: '9:00', endTime: '10:00'),
          ],
        ),
        Staff(
          id: 'staff_shri',
          collegeId: collegeId,
          employeeId: '06',
          name: 'Shrinidhi',
          email: 'shrinidhi@gmail.com',
          departmentId: '',
          subjectsCanTeach: ['PROJ', 'CN LAB'],
          maxClassesPerDay: 4,
          maxClassesPerWeek: 20,
          unavailableTimes: [
            UnavailableTime(dayOfWeek: 'Monday', startTime: '9:00', endTime: '10:00'),
            UnavailableTime(dayOfWeek: 'Tuesday', startTime: '11:00', endTime: '12:00'),
            UnavailableTime(dayOfWeek: 'Wednesday', startTime: '1:15', endTime: '2:15'),
            UnavailableTime(dayOfWeek: 'Thursday', startTime: '12:15', endTime: '1:15'),
          ],
        ),
        Staff(
          id: 'staff_bhanu',
          collegeId: collegeId,
          employeeId: '05',
          name: 'Bhanu kumar',
          email: 'Bhanu@gmail.com',
          departmentId: '',
          subjectsCanTeach: ['IPR'],
          maxClassesPerDay: 3,
          maxClassesPerWeek: 20,
          unavailableTimes: [
            UnavailableTime(dayOfWeek: 'Monday', startTime: '11:15', endTime: '12:15'),
            UnavailableTime(dayOfWeek: 'Tuesday', startTime: '2:00', endTime: '3:00'),
            UnavailableTime(dayOfWeek: 'Wednesday', startTime: '10:00', endTime: '11:00'),
            UnavailableTime(dayOfWeek: 'Thursday', startTime: '3:00', endTime: '4:00'),
          ],
        ),
        Staff(
          id: 'staff_nirmal',
          collegeId: collegeId,
          employeeId: '02',
          name: 'Mr Nirmal kumar nigam',
          email: 'nirmal@gmail.com',
          departmentId: '',
          subjectsCanTeach: ['CN'],
          maxClassesPerDay: 4,
          maxClassesPerWeek: 20,
          unavailableTimes: [
            UnavailableTime(dayOfWeek: 'Monday', startTime: '10:00', endTime: '11:00'),
            UnavailableTime(dayOfWeek: 'Tuesday', startTime: '9:00', endTime: '10:00'),
            UnavailableTime(dayOfWeek: 'Wednesday', startTime: '2:00', endTime: '3:00'),
            UnavailableTime(dayOfWeek: 'Thursday', startTime: '3:00', endTime: '4:00'),
            UnavailableTime(dayOfWeek: 'Friday', startTime: '12:15', endTime: '1:15'),
          ],
        ),
        Staff(
          id: 'staff_gayatri',
          collegeId: collegeId,
          employeeId: '03',
          name: 'Gayatri devadiga',
          email: 'gayatri@gmail.com',
          departmentId: '',
          subjectsCanTeach: ['TOC', 'IR'],
          maxClassesPerDay: 4,
          maxClassesPerWeek: 20,
          unavailableTimes: [
            UnavailableTime(dayOfWeek: 'Monday', startTime: '3:00', endTime: '4:00'),
            UnavailableTime(dayOfWeek: 'Tuesday', startTime: '2:00', endTime: '3:00'),
            UnavailableTime(dayOfWeek: 'Wednesday', startTime: '9:00', endTime: '10:00'),
            UnavailableTime(dayOfWeek: 'Thursday', startTime: '11:15', endTime: '12:15'),
            UnavailableTime(dayOfWeek: 'Friday', startTime: '10:00', endTime: '11:00'),
          ],
        ),
        Staff(
          id: 'staff_pravin',
          collegeId: collegeId,
          employeeId: '04',
          name: 'Pravin kumar',
          email: 'pravin@gmail.com',
          departmentId: '',
          subjectsCanTeach: ['DVL', 'YOGA'],
          maxClassesPerDay: 3,
          maxClassesPerWeek: 20,
          unavailableTimes: [
            UnavailableTime(dayOfWeek: 'Monday', startTime: '9:00', endTime: '10:00'),
            UnavailableTime(dayOfWeek: 'Tuesday', startTime: '10:00', endTime: '11:00'),
            UnavailableTime(dayOfWeek: 'Wednesday', startTime: '3:00', endTime: '4:00'),
            UnavailableTime(dayOfWeek: 'Thursday', startTime: '2:00', endTime: '3:00'),
            UnavailableTime(dayOfWeek: 'Friday', startTime: '11:00', endTime: '12:00'),
          ],
        ),
      ];

      final subjects = [
        Subject(id: 'sub_cnlab', collegeId: collegeId, departmentId: 'dept_cse', courseId: 'course_cse', sectionId: 'sec_aiml', semester: 5, subjectName: 'CN LAB', subjectCode: 'BCS502', hoursPerWeek: 1, assignedTeacherIds: ['staff_shri']),
        Subject(id: 'sub_proj', collegeId: collegeId, departmentId: 'dept_cse', courseId: 'course_cse', sectionId: 'sec_aiml', semester: 5, subjectName: 'PROJ', subjectCode: 'BCI586', hoursPerWeek: 2, assignedTeacherIds: ['staff_shri']),
        Subject(id: 'sub_dvl', collegeId: collegeId, departmentId: 'dept_cse', courseId: 'course_cse', sectionId: 'sec_aiml', semester: 5, subjectName: 'DVL', subjectCode: 'BAIL504', hoursPerWeek: 1, assignedTeacherIds: ['staff_pravin']),
        Subject(id: 'sub_sepm', collegeId: collegeId, departmentId: 'dept_cse', courseId: 'course_cse', sectionId: 'sec_aiml', semester: 5, subjectName: 'SEPM', subjectCode: 'BCS501', hoursPerWeek: 3, assignedTeacherIds: ['staff_kumar']),
        Subject(id: 'sub_ewaste', collegeId: collegeId, departmentId: 'dept_cse', courseId: 'course_cse', sectionId: 'sec_aiml', semester: 5, subjectName: 'E-WASTE', subjectCode: 'BCS508', hoursPerWeek: 1, assignedTeacherIds: ['staff_amresh']),
        Subject(id: 'sub_ipr', collegeId: collegeId, departmentId: 'dept_cse', courseId: 'course_cse', sectionId: 'sec_aiml', semester: 5, subjectName: 'IPR', subjectCode: 'BRMK557', hoursPerWeek: 4, assignedTeacherIds: ['staff_bhanu']),
        Subject(id: 'sub_cn', collegeId: collegeId, departmentId: 'dept_cse', courseId: 'course_cse', sectionId: 'sec_aiml', semester: 5, subjectName: 'cn', subjectCode: 'BCS502', hoursPerWeek: 3, assignedTeacherIds: ['staff_nirmal']),
        Subject(id: 'sub_yoga', collegeId: collegeId, departmentId: 'dept_cse', courseId: 'course_cse', sectionId: 'sec_aiml', semester: 5, subjectName: 'YOGA', subjectCode: 'BYOK559', hoursPerWeek: 1, assignedTeacherIds: ['staff_pravin']),
        Subject(id: 'sub_ir', collegeId: collegeId, departmentId: 'dept_cse', courseId: 'course_cse', sectionId: 'sec_aiml', semester: 5, subjectName: 'IR', subjectCode: 'BAI515B', hoursPerWeek: 3, assignedTeacherIds: ['staff_gayatri']),
        Subject(id: 'sub_toc', collegeId: collegeId, departmentId: 'dept_cse', courseId: 'course_cse', sectionId: 'sec_aiml', semester: 5, subjectName: 'TOC', subjectCode: 'BCS503', hoursPerWeek: 5, assignedTeacherIds: ['staff_gayatri']),
      ];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [secAiml],
        subjects: subjects,
        staffList: staffList,
        rooms: [room103, room105],
        timeSlots: academicTimeSlots,
        availabilities: [],
        workingDays: days,
      );

      // Verify overall success
      expect(result.isSuccess, isTrue, reason: 'Generator should successfully satisfy all constraints.');
      expect(result.conflicts.where((c) => c.isHard).isEmpty, isTrue, reason: 'Zero hard conflicts expected.');
      expect(result.totalClassesScheduled, equals(24), reason: 'All 24 subject hours must be scheduled.');

      // Verify TOC specifically
      final tocEntries = result.entries.where((e) => e.subjectId == 'sub_toc').toList();
      expect(tocEntries.length, equals(5), reason: 'All 5 TOC sessions must be scheduled.');

      // Verify Gayatri constraints
      final gayatriEntries = result.entries.where((e) => e.teacherId == 'staff_gayatri').toList();
      expect(gayatriEntries.length, equals(8), reason: 'Gayatri teaches exactly 5 TOC + 3 IR = 8 hours.');

      // Verify Gayatri daily teaching limit <= 4
      final gayatriPerDay = <String, int>{};
      for (final e in gayatriEntries) {
        gayatriPerDay[e.dayOfWeek] = (gayatriPerDay[e.dayOfWeek] ?? 0) + 1;
      }
      for (final dayCount in gayatriPerDay.values) {
        expect(dayCount <= 4, isTrue, reason: 'Gayatri must never exceed 4 classes/day.');
      }

      // Verify Room Capacity: all scheduled in room103 (capacity 90 >= 57)
      for (final e in result.entries) {
        expect(e.roomId, equals('room_103'), reason: 'Room 105 has capacity 30 (< 57), so only Room 103 can host.');
      }

      // Verify Section Occupancy: max 1 class per period
      final secOccupancy = <String>{};
      for (final e in result.entries) {
        final key = '${e.dayOfWeek}_${e.periodNumber}';
        expect(secOccupancy.contains(key), isFalse, reason: 'Section cannot have 2 classes at the same time: $key');
        secOccupancy.add(key);
      }
    });

    test('Backtracking State Restoration: Undo correctly releases occupancy and daily counts when dead end reached', () {
      // 1 day with 2 periods
      final oneDay = ['Monday'];
      final twoPeriods = [
        TimeSlot(id: 'ts_1', collegeId: collegeId, periodNumber: 1, startTime: '09:00', endTime: '10:00', order: 1),
        TimeSlot(id: 'ts_2', collegeId: collegeId, periodNumber: 2, startTime: '10:00', endTime: '11:00', order: 2),
      ];

      final tightSec = Section(
        id: 'sec_t',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'course_cse',
        academicYear: '2026-2027',
        semester: 3,
        sectionName: 'T',
        studentCount: 40,
      );

      // Prof X can only teach Period 2 (unavailable Period 1)
      final profX = Staff(
        id: 'prof_x',
        collegeId: collegeId,
        employeeId: 'X01',
        name: 'Prof X',
        email: 'x@college.edu',
        departmentId: '',
        subjectsCanTeach: ['SubX'],
        maxClassesPerDay: 1,
        unavailableTimes: [
          UnavailableTime(dayOfWeek: 'Monday', startTime: '09:00', endTime: '10:00'),
        ],
      );

      // Prof Y can teach both Period 1 and Period 2
      final profY = Staff(
        id: 'prof_y',
        collegeId: collegeId,
        employeeId: 'Y01',
        name: 'Prof Y',
        email: 'y@college.edu',
        departmentId: '',
        subjectsCanTeach: ['SubY'],
        maxClassesPerDay: 1,
      );

      // SubY needs 1 hr, SubX needs 1 hr
      final subjects = [
        Subject(id: 'sub_y', collegeId: collegeId, departmentId: '', courseId: '', sectionId: 'sec_t', semester: 3, subjectName: 'SubY', subjectCode: 'SY', hoursPerWeek: 1, assignedTeacherIds: ['prof_y']),
        Subject(id: 'sub_x', collegeId: collegeId, departmentId: '', courseId: '', sectionId: 'sec_t', semester: 3, subjectName: 'SubX', subjectCode: 'SX', hoursPerWeek: 1, assignedTeacherIds: ['prof_x']),
      ];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [tightSec],
        subjects: subjects,
        staffList: [profX, profY],
        rooms: [room103],
        timeSlots: twoPeriods,
        availabilities: [],
        workingDays: oneDay,
      );

      expect(result.isSuccess, isTrue);
      expect(result.totalClassesScheduled, equals(2));

      final subXEntry = result.entries.firstWhere((e) => e.subjectId == 'sub_x');
      final subYEntry = result.entries.firstWhere((e) => e.subjectId == 'sub_y');

      expect(subXEntry.periodNumber, equals(2), reason: 'Prof X is only available on Period 2.');
      expect(subYEntry.periodNumber, equals(1), reason: 'Prof Y must yield Period 2 to Prof X via backtracking.');
    });

    test('TASK 6: Genuinely impossible data produces structured diagnostic conflict breakdown', () {
      // 1 day with 1 period
      final oneDay = ['Monday'];
      final onePeriod = [
        TimeSlot(id: 'ts_1', collegeId: collegeId, periodNumber: 1, startTime: '09:00', endTime: '10:00', order: 1),
      ];

      final prof = Staff(
        id: 'prof_solo',
        collegeId: collegeId,
        employeeId: 'S01',
        name: 'Prof Solo',
        email: 'solo@college.edu',
        departmentId: '',
        subjectsCanTeach: ['Math', 'Physics'],
        maxClassesPerDay: 4,
      );

      final sec = Section(
        id: 'sec_s',
        collegeId: collegeId,
        departmentId: '',
        courseId: '',
        academicYear: '2026-2027',
        semester: 1,
        sectionName: 'S',
        studentCount: 30,
      );

      // Two 1-hour subjects competing for only 1 period
      final subjects = [
        Subject(id: 'sub_math', collegeId: collegeId, departmentId: '', courseId: '', sectionId: 'sec_s', semester: 1, subjectName: 'Math', subjectCode: 'M1', hoursPerWeek: 1, assignedTeacherIds: ['prof_solo']),
        Subject(id: 'sub_physics', collegeId: collegeId, departmentId: '', courseId: '', sectionId: 'sec_s', semester: 1, subjectName: 'Physics', subjectCode: 'P1', hoursPerWeek: 1, assignedTeacherIds: ['prof_solo']),
      ];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [sec],
        subjects: subjects,
        staffList: [prof],
        rooms: [room103],
        timeSlots: onePeriod,
        availabilities: [],
        workingDays: oneDay,
      );

      expect(result.isSuccess, isFalse);
      expect(result.conflicts.isNotEmpty, isTrue);

      final conflict = result.conflicts.firstWhere((c) => c.type == 'incompleteHours');
      expect(conflict.description, contains('Candidate slots checked: 1'));
      expect(conflict.description, contains('Section already has class'));
      expect(conflict.suggestion, isNotNull);
    });

    test('Stale entry isolation: Target section existing entries are purged and do not block new schedule', () {
      // Existing entry for secAiml occupying Monday P1
      final staleEntry = TimetableEntry(
        id: 'stale_1',
        collegeId: collegeId,
        versionId: 'old_ver',
        dayOfWeek: 'Monday',
        periodNumber: 1,
        timeSlotId: 'ts_1',
        sectionId: 'sec_aiml',
        subjectId: 'sub_toc',
        teacherId: 'staff_gayatri',
        roomId: 'room_103',
        status: 'draft',
      );

      final prof = Staff(
        id: 'staff_solo',
        collegeId: collegeId,
        employeeId: 'S01',
        name: 'Prof Solo',
        email: 'solo@college.edu',
        departmentId: '',
        subjectsCanTeach: ['TOC'],
        maxClassesPerDay: 4,
      );

      final subj = Subject(
        id: 'sub_toc_test',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'course_cse',
        sectionId: 'sec_aiml',
        semester: 5,
        subjectName: 'TOC',
        subjectCode: 'BCS503',
        hoursPerWeek: 1,
        assignedTeacherIds: ['staff_solo'],
      );

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [secAiml],
        subjects: [subj],
        staffList: [prof],
        rooms: [room103],
        timeSlots: academicTimeSlots,
        availabilities: [],
        workingDays: days,
        targetSectionId: 'sec_aiml',
        existingEntries: [staleEntry],
      );

      expect(result.isSuccess, isTrue);
      expect(result.entries.any((e) => e.id == 'stale_1'), isFalse, reason: 'Stale target section entries must be excluded.');
      expect(result.newlyScheduledEntries.length, equals(1));
    });

    test('Teacher Availability: Teacher with unavailable periods is strictly never scheduled in them', () {
      final prof = Staff(
        id: 'prof_unavail',
        collegeId: collegeId,
        employeeId: 'U01',
        name: 'Prof Unavail',
        email: 'u@college.edu',
        departmentId: '',
        subjectsCanTeach: ['Math'],
        maxClassesPerDay: 4,
        unavailableTimes: [
          UnavailableTime(dayOfWeek: 'Monday', startTime: '08:50', endTime: '09:50'), // P1
          UnavailableTime(dayOfWeek: 'Tuesday', startTime: '09:50', endTime: '10:50'), // P2
          UnavailableTime(dayOfWeek: 'Wednesday', startTime: '11:10', endTime: '12:10'), // P3
        ],
      );

      final subj = Subject(
        id: 'sub_math_3',
        collegeId: collegeId,
        departmentId: '',
        courseId: '',
        sectionId: 'sec_aiml',
        semester: 5,
        subjectName: 'Math',
        subjectCode: 'M101',
        hoursPerWeek: 3,
        assignedTeacherIds: ['prof_unavail'],
      );

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [secAiml],
        subjects: [subj],
        staffList: [prof],
        rooms: [room103],
        timeSlots: academicTimeSlots,
        availabilities: [],
        workingDays: days,
      );

      expect(result.isSuccess, isTrue);
      for (final e in result.entries) {
        if (e.dayOfWeek == 'Monday') expect(e.periodNumber != 1, isTrue);
        if (e.dayOfWeek == 'Tuesday') expect(e.periodNumber != 2, isTrue);
        if (e.dayOfWeek == 'Wednesday') expect(e.periodNumber != 3, isTrue);
      }
    });

    test('Room Capacity: Section of 57 students is NEVER scheduled in a 30-capacity room', () {
      final prof = Staff(
        id: 'prof_cap',
        collegeId: collegeId,
        employeeId: 'C01',
        name: 'Prof Cap',
        email: 'c@college.edu',
        departmentId: '',
        subjectsCanTeach: ['Math'],
        maxClassesPerDay: 4,
      );

      final subj = Subject(
        id: 'sub_cap',
        collegeId: collegeId,
        departmentId: '',
        courseId: '',
        sectionId: 'sec_aiml',
        semester: 5,
        subjectName: 'Math',
        subjectCode: 'M101',
        hoursPerWeek: 2,
        assignedTeacherIds: ['prof_cap'],
      );

      // Only room105 (capacity 30) is provided. secAiml has 57 students.
      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [secAiml],
        subjects: [subj],
        staffList: [prof],
        rooms: [room105],
        timeSlots: academicTimeSlots,
        availabilities: [],
        workingDays: days,
      );

      expect(result.isSuccess, isFalse);
      expect(result.conflicts.any((c) => c.type == 'capacityConflict'), isTrue);
    });

    test('Daily Teaching Limit: Professor with limit=2 is never scheduled for >2 classes on any single day', () {
      final prof = Staff(
        id: 'prof_lim2',
        collegeId: collegeId,
        employeeId: 'L01',
        name: 'Prof Lim2',
        email: 'l@college.edu',
        departmentId: '',
        subjectsCanTeach: ['Physics'],
        maxClassesPerDay: 2, // Strict limit 2
      );

      final subj = Subject(
        id: 'sub_phy_4',
        collegeId: collegeId,
        departmentId: '',
        courseId: '',
        sectionId: 'sec_aiml',
        semester: 5,
        subjectName: 'Physics',
        subjectCode: 'PHY',
        hoursPerWeek: 4,
        assignedTeacherIds: ['prof_lim2'],
      );

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [secAiml],
        subjects: [subj],
        staffList: [prof],
        rooms: [room103],
        timeSlots: academicTimeSlots,
        availabilities: [],
        workingDays: days,
      );

      expect(result.isSuccess, isTrue);
      expect(result.totalClassesScheduled, equals(4));

      final perDay = <String, int>{};
      for (final e in result.entries) {
        perDay[e.dayOfWeek] = (perDay[e.dayOfWeek] ?? 0) + 1;
      }
      for (final count in perDay.values) {
        expect(count <= 2, isTrue, reason: 'Must strictly respect maxClassesPerDay=2');
      }
    });

    test('Multi-Section Room & Teacher Occupancy Isolation: No room or teacher double-booking across sections', () {
      final sec1 = Section(id: 's1', collegeId: collegeId, departmentId: '', courseId: '', academicYear: '2026', semester: 1, sectionName: 'S1', studentCount: 40);
      final sec2 = Section(id: 's2', collegeId: collegeId, departmentId: '', courseId: '', academicYear: '2026', semester: 1, sectionName: 'S2', studentCount: 40);

      final profCommon = Staff(
        id: 'prof_com',
        collegeId: collegeId,
        employeeId: 'COM',
        name: 'Prof Common',
        email: 'com@college.edu',
        departmentId: '',
        subjectsCanTeach: ['Math S1', 'Math S2'],
        maxClassesPerDay: 4,
      );

      final subj1 = Subject(id: 'sub_s1', collegeId: collegeId, departmentId: '', courseId: '', sectionId: 's1', semester: 1, subjectName: 'Math S1', subjectCode: 'M1', hoursPerWeek: 2, assignedTeacherIds: ['prof_com']);
      final subj2 = Subject(id: 'sub_s2', collegeId: collegeId, departmentId: '', courseId: '', sectionId: 's2', semester: 1, subjectName: 'Math S2', subjectCode: 'M2', hoursPerWeek: 2, assignedTeacherIds: ['prof_com']);

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [sec1, sec2],
        subjects: [subj1, subj2],
        staffList: [profCommon],
        rooms: [room103], // Only 1 classroom
        timeSlots: academicTimeSlots,
        availabilities: [],
        workingDays: days,
      );

      expect(result.isSuccess, isTrue);
      expect(result.totalClassesScheduled, equals(4));

      // No double booking of profCommon
      final profSlots = <String>{};
      for (final e in result.entries) {
        final key = '${e.dayOfWeek}_${e.periodNumber}';
        expect(profSlots.contains(key), isFalse, reason: 'Teacher double booking: $key');
        profSlots.add(key);
      }

      // No double booking of room103
      final roomSlots = <String>{};
      for (final e in result.entries) {
        final key = '${e.dayOfWeek}_${e.periodNumber}';
        expect(roomSlots.contains(key), isFalse, reason: 'Room double booking: $key');
        roomSlots.add(key);
      }
    });
  });
}
