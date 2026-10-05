import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/services/services.dart';
import 'package:time_table/features/timetable/timetable_utils.dart';

void main() {
  const collegeId = 'test_college';

  final standardSlots = [
    TimeSlot(id: 'ts_1', collegeId: collegeId, periodNumber: 1, startTime: '09:00', endTime: '10:00', order: 1),
    TimeSlot(id: 'ts_2', collegeId: collegeId, periodNumber: 2, startTime: '10:00', endTime: '11:00', order: 2),
    TimeSlot(id: 'ts_break', collegeId: collegeId, periodNumber: 0, startTime: '11:00', endTime: '11:15', order: 3, isBreak: true),
    TimeSlot(id: 'ts_3', collegeId: collegeId, periodNumber: 3, startTime: '11:15', endTime: '12:15', order: 4),
    TimeSlot(id: 'ts_4', collegeId: collegeId, periodNumber: 4, startTime: '12:15', endTime: '13:15', order: 5),
    TimeSlot(id: 'ts_5', collegeId: collegeId, periodNumber: 5, startTime: '14:00', endTime: '15:00', order: 6),
    TimeSlot(id: 'ts_6', collegeId: collegeId, periodNumber: 6, startTime: '15:00', endTime: '16:00', order: 7),
  ];

  final testClassroom1 = Room(
    id: 'room_101',
    collegeId: collegeId,
    roomNumber: 'LH 101',
    capacity: 60,
    roomType: 'Classroom',
  );

  final testClassroom2 = Room(
    id: 'room_102',
    collegeId: collegeId,
    roomNumber: 'LH 102',
    capacity: 60,
    roomType: 'Classroom',
  );

  final testLabRoom1 = Room(
    id: 'room_lab_1',
    collegeId: collegeId,
    roomNumber: 'CS Lab 1',
    capacity: 60,
    roomType: 'Laboratory',
  );

  final testLabRoom2 = Room(
    id: 'room_lab_2',
    collegeId: collegeId,
    roomNumber: 'CS Lab 2',
    capacity: 60,
    roomType: 'Laboratory',
  );

  final allRooms = [testClassroom1, testClassroom2, testLabRoom1, testLabRoom2];

  final testSectionA = Section(
    id: 'sec_a',
    collegeId: collegeId,
    departmentId: 'dept_cs',
    courseId: 'course_btech',
    academicYear: '2024-2025',
    semester: 3,
    sectionName: 'CS-A',
    studentCount: 40,
    batches: ['B1', 'B2'],
  );

  final testSectionB = Section(
    id: 'sec_b',
    collegeId: collegeId,
    departmentId: 'dept_cs',
    courseId: 'course_btech',
    academicYear: '2024-2025',
    semester: 3,
    sectionName: 'CS-B',
    studentCount: 40,
    batches: ['B1', 'B2'],
  );

  final allSections = [testSectionA, testSectionB];

  final testStaffMath = Staff(
    id: 'staff_math',
    collegeId: collegeId,
    employeeId: 'EMP_M',
    name: 'Prof. Gauss',
    email: 'gauss@college.edu',
    departmentId: 'dept_cs',
    subjectsCanTeach: ['sub_maths'],
  );

  final testStaffPhysics = Staff(
    id: 'staff_physics',
    collegeId: collegeId,
    employeeId: 'EMP_P',
    name: 'Prof. Newton',
    email: 'newton@college.edu',
    departmentId: 'dept_cs',
    subjectsCanTeach: ['sub_physics'],
  );

  final allStaff = [testStaffMath, testStaffPhysics];

  final subjectMath = Subject(
    id: 'sub_maths',
    collegeId: collegeId,
    departmentId: 'dept_cs',
    courseId: 'course_btech',
    semester: 3,
    subjectCode: 'MA301',
    subjectName: 'Discrete Mathematics',
    courseShortName: 'DM',
    hoursPerWeek: 4,
    subjectType: 'Theory',
    requiredRoomType: 'Classroom',
    assignedTeacherIds: ['staff_math'],
  );

  final subjectPhysics = Subject(
    id: 'sub_physics',
    collegeId: collegeId,
    departmentId: 'dept_cs',
    courseId: 'course_btech',
    semester: 3,
    subjectCode: 'PH301',
    subjectName: 'Quantum Physics',
    courseShortName: 'QP',
    hoursPerWeek: 3,
    subjectType: 'Theory',
    requiredRoomType: 'Classroom',
    assignedTeacherIds: ['staff_physics'],
  );

  final allSubjects = [subjectMath, subjectPhysics];
  final workingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  group('Activity / Event Timetable System Regression Tests', () {
    // -------------------------------------------------------------------------
    // TEST 1: Subject Class still works exactly as before
    // -------------------------------------------------------------------------
    test('1. Subject Class still works exactly as before with normal conflict validation', () {
      final normalClass = TimetableEntry(
        id: 'entry_math_1',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 1,
        sectionId: 'sec_a',
        subjectId: 'sub_maths',
        teacherId: 'staff_math',
        roomId: 'room_101',
        entryType: 'class',
        status: 'draft',
      );

      expect(normalClass.isActivity, isFalse);
      expect(normalClass.entryType, equals('class'));

      // Validate proposed valid class
      final resultValid = ConflictValidator.validateProposedEntries(
        collegeId: collegeId,
        proposedEntries: [normalClass],
        existingEntries: [],
        sections: allSections,
        subjects: allSubjects,
        staffList: allStaff,
        rooms: allRooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );
      expect(resultValid.isValid, isTrue);

      // Validate collision (same teacher double-booked)
      final conflictingTeacherClass = TimetableEntry(
        id: 'entry_math_2',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 1,
        sectionId: 'sec_b',
        subjectId: 'sub_maths',
        teacherId: 'staff_math',
        roomId: 'room_102',
        entryType: 'class',
        status: 'draft',
      );

      final resultConflict = ConflictValidator.validateProposedEntries(
        collegeId: collegeId,
        proposedEntries: [conflictingTeacherClass],
        existingEntries: [normalClass],
        sections: allSections,
        subjects: allSubjects,
        staffList: allStaff,
        rooms: allRooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );
      expect(resultConflict.isValid, isFalse);
      expect(resultConflict.hardConflicts.any((c) => c.type == 'teacherConflict'), isTrue);
    });

    // -------------------------------------------------------------------------
    // TEST 2: Activity / Event can be created without a subject
    // -------------------------------------------------------------------------
    test('2. Activity / Event can be created without a subject', () {
      final activity = TimetableEntry(
        id: 'act_1',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 1,
        sectionId: 'sec_a',
        subjectId: '',
        teacherId: '',
        roomId: 'room_101',
        entryType: 'activity',
        activityName: 'Placement Orientation',
        description: 'Pre-placement training by industry experts',
        status: 'draft',
      );

      expect(activity.isActivity, isTrue);
      expect(activity.subjectId, isEmpty);
      expect(activity.activityName, equals('Placement Orientation'));

      final result = ConflictValidator.validateProposedEntries(
        collegeId: collegeId,
        proposedEntries: [activity],
        existingEntries: [],
        sections: allSections,
        subjects: allSubjects,
        staffList: allStaff,
        rooms: allRooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(result.isValid, isTrue);
      expect(result.hardConflicts, isEmpty);
    });

    // -------------------------------------------------------------------------
    // TEST 3: Activity / Event can be created without a professor
    // -------------------------------------------------------------------------
    test('3. Activity / Event can be created without a professor', () {
      final activity = TimetableEntry(
        id: 'act_seminar',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Tuesday',
        periodNumber: 3,
        sectionId: 'sec_a',
        subjectId: '',
        teacherId: '',
        roomId: 'room_101',
        entryType: 'activity',
        activityName: 'Invited Guest Seminar',
        status: 'draft',
      );

      expect(activity.isActivity, isTrue);
      expect(activity.teacherId, isEmpty);

      final result = ConflictValidator.validateProposedEntries(
        collegeId: collegeId,
        proposedEntries: [activity],
        existingEntries: [],
        sections: allSections,
        subjects: allSubjects,
        staffList: allStaff,
        rooms: allRooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(result.isValid, isTrue);
      expect(result.hardConflicts.any((c) => c.type == 'teacherDoubleBooking'), isFalse);
    });

    // -------------------------------------------------------------------------
    // TEST 4: Activity / Event can be created without a venue
    // -------------------------------------------------------------------------
    test('4. Activity / Event can be created without a venue (off-campus/online)', () {
      final activityNoVenue = TimetableEntry(
        id: 'act_outdoor',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Wednesday',
        periodNumber: 4,
        sectionId: 'sec_a',
        subjectId: '',
        teacherId: '',
        roomId: '',
        entryType: 'activity',
        activityName: 'Field Trip / Off-Campus Sports',
        status: 'draft',
      );

      expect(activityNoVenue.isActivity, isTrue);
      expect(activityNoVenue.roomId, isEmpty);

      final result = ConflictValidator.validateProposedEntries(
        collegeId: collegeId,
        proposedEntries: [activityNoVenue],
        existingEntries: [],
        sections: allSections,
        subjects: allSubjects,
        staffList: allStaff,
        rooms: allRooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(result.isValid, isTrue);
      expect(result.hardConflicts.any((c) => c.type == 'roomDoubleBooking'), isFalse);
    });

    // -------------------------------------------------------------------------
    // TEST 5: Activity occupies the section's timetable slot
    // -------------------------------------------------------------------------
    test('5. Activity occupies the section timetable slot and blocks other section entries', () {
      final existingActivity = TimetableEntry(
        id: 'act_existing',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 2,
        sectionId: 'sec_a',
        subjectId: '',
        teacherId: '',
        roomId: '',
        entryType: 'activity',
        activityName: 'Mentorship Session',
        status: 'draft',
      );

      // Attempting to schedule a normal theory class for Sec A on Monday P2
      final proposedClass = TimetableEntry(
        id: 'class_clashing',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 2,
        sectionId: 'sec_a',
        subjectId: 'sub_maths',
        teacherId: 'staff_math',
        roomId: 'room_101',
        entryType: 'class',
        status: 'draft',
      );

      final result = ConflictValidator.validateProposedEntries(
        collegeId: collegeId,
        proposedEntries: [proposedClass],
        existingEntries: [existingActivity],
        sections: allSections,
        subjects: allSubjects,
        staffList: allStaff,
        rooms: allRooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(result.isValid, isFalse);
      expect(result.hardConflicts.any((c) => c.type == 'sectionConflict'), isTrue);
      expect(result.hardConflicts.first.description, contains('Mentorship Session'));
    });

    // -------------------------------------------------------------------------
    // TEST 6: Activity with a venue detects venue conflicts
    // -------------------------------------------------------------------------
    test('6. Activity with a venue detects venue conflicts when another class/activity uses same venue', () {
      final existingActivity = TimetableEntry(
        id: 'act_hall',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Friday',
        periodNumber: 5,
        sectionId: 'sec_a',
        subjectId: '',
        teacherId: '',
        roomId: 'room_101',
        entryType: 'activity',
        activityName: 'Placement Aptitude Test',
        status: 'draft',
      );

      // Another section trying to book room_101 at the same time
      final proposedSecB = TimetableEntry(
        id: 'class_sec_b',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Friday',
        periodNumber: 5,
        sectionId: 'sec_b',
        subjectId: 'sub_physics',
        teacherId: 'staff_physics',
        roomId: 'room_101',
        entryType: 'class',
        status: 'draft',
      );

      final result = ConflictValidator.validateProposedEntries(
        collegeId: collegeId,
        proposedEntries: [proposedSecB],
        existingEntries: [existingActivity],
        sections: allSections,
        subjects: allSubjects,
        staffList: allStaff,
        rooms: allRooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(result.isValid, isFalse);
      expect(result.hardConflicts.any((c) => c.type == 'roomConflict'), isTrue);
    });

    // -------------------------------------------------------------------------
    // TEST 7: Activity without a venue does not produce a venue conflict
    // -------------------------------------------------------------------------
    test('7. Multiple activities without a venue at the same period do NOT produce venue conflicts', () {
      final activityA = TimetableEntry(
        id: 'act_a',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 5,
        sectionId: 'sec_a',
        subjectId: '',
        teacherId: '',
        roomId: '', // No venue
        entryType: 'activity',
        activityName: 'Section A Project Work',
        status: 'draft',
      );

      final activityB = TimetableEntry(
        id: 'act_b',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 5,
        sectionId: 'sec_b',
        subjectId: '',
        teacherId: '',
        roomId: '', // No venue
        entryType: 'activity',
        activityName: 'Section B Outdoor Activity',
        status: 'draft',
      );

      final result = ConflictValidator.validateProposedEntries(
        collegeId: collegeId,
        proposedEntries: [activityB],
        existingEntries: [activityA],
        sections: allSections,
        subjects: allSubjects,
        staffList: allStaff,
        rooms: allRooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(result.isValid, isTrue);
      expect(result.hardConflicts, isEmpty);
    });

    // -------------------------------------------------------------------------
    // TEST 8: Activity does not produce a professor conflict
    // -------------------------------------------------------------------------
    test('8. Activity has no professor and never produces a professor conflict', () {
      final normalClass = TimetableEntry(
        id: 'class_prof_gauss',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 1,
        sectionId: 'sec_b',
        subjectId: 'sub_maths',
        teacherId: 'staff_math',
        roomId: 'room_102',
        entryType: 'class',
        status: 'draft',
      );

      final activitySecA = TimetableEntry(
        id: 'act_no_prof',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 1,
        sectionId: 'sec_a',
        subjectId: '',
        teacherId: '',
        roomId: 'room_101',
        entryType: 'activity',
        activityName: 'Soft Skills Training',
        status: 'draft',
      );

      final result = ConflictValidator.validateProposedEntries(
        collegeId: collegeId,
        proposedEntries: [activitySecA],
        existingEntries: [normalClass],
        sections: allSections,
        subjects: allSubjects,
        staffList: allStaff,
        rooms: allRooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(result.isValid, isTrue);
      expect(result.hardConflicts, isEmpty);
    });

    // -------------------------------------------------------------------------
    // TEST 9: Activity does not contribute to subject weekly hours
    // -------------------------------------------------------------------------
    test('9. Activity does not contribute to subject weekly hours or completion calculations', () {
      final mathEntry1 = TimetableEntry(
        id: 'm1',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 1,
        sectionId: 'sec_a',
        subjectId: 'sub_maths',
        teacherId: 'staff_math',
        roomId: 'room_101',
        entryType: 'class',
      );

      final mathEntry2 = TimetableEntry(
        id: 'm2',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Tuesday',
        periodNumber: 1,
        sectionId: 'sec_a',
        subjectId: 'sub_maths',
        teacherId: 'staff_math',
        roomId: 'room_101',
        entryType: 'class',
      );

      final activityEntry = TimetableEntry(
        id: 'act_1',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Wednesday',
        periodNumber: 1,
        sectionId: 'sec_a',
        subjectId: '',
        teacherId: '',
        roomId: 'room_101',
        entryType: 'activity',
        activityName: 'Code Jam',
      );

      final entries = [mathEntry1, mathEntry2, activityEntry];

      // Count subject hours
      final mathCount = entries.where((e) => !e.isActivity && e.subjectId == 'sub_maths').length;
      expect(mathCount, equals(2));

      // Subject hours for activity is 0
      final activitySubjectHours = entries.where((e) => e.isActivity && e.subjectId.isNotEmpty).length;
      expect(activitySubjectHours, equals(0));
    });

    // -------------------------------------------------------------------------
    // TEST 10: Activity does not contribute to professor workload
    // -------------------------------------------------------------------------
    test('10. Activity does not contribute to professor workload or teaching hours', () {
      final mathClass = TimetableEntry(
        id: 'c1',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 1,
        sectionId: 'sec_a',
        subjectId: 'sub_maths',
        teacherId: 'staff_math',
        roomId: 'room_101',
        entryType: 'class',
      );

      final activity = TimetableEntry(
        id: 'a1',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 2,
        sectionId: 'sec_a',
        subjectId: '',
        teacherId: '',
        roomId: 'room_101',
        entryType: 'activity',
        activityName: 'Hackathon Prep',
      );

      final entries = [mathClass, activity];
      final workload = calculateProfessorWorkload(
        teacher: testStaffMath,
        allSubjects: allSubjects,
        sectionMap: {'sec_a': testSectionA, 'sec_b': testSectionB},
        entries: entries,
        subjectMap: {'sub_maths': subjectMath},
      );

      expect(workload.scheduledTotal, equals(1));
      expect(workload.scheduledTheory, equals(1));
      expect(workload.scheduledLab, equals(0));
    });

    // -------------------------------------------------------------------------
    // TEST 11: Timetable generator respects activity occupancy
    // -------------------------------------------------------------------------
    test('11. Generator respects pre-existing activity entries and does not overwrite their slots', () {
      // Sec A has an Activity already scheduled on Monday Period 1
      final preExistingActivity = TimetableEntry(
        id: 'act_pre_existing',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 1,
        sectionId: 'sec_a',
        subjectId: '',
        teacherId: '',
        roomId: 'room_101',
        entryType: 'activity',
        activityName: 'Morning Assembly',
        status: 'draft',
      );

      final genResult = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [testSectionA],
        subjects: [subjectMath], // requires 4 weekly hours
        staffList: [testStaffMath],
        rooms: [testClassroom1, testClassroom2],
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
        existingEntries: [preExistingActivity],
      );

      expect(genResult.isSuccess, isTrue);

      // The pre-existing activity must be preserved
      final scheduled = genResult.entries;
      final mondayP1Entries = scheduled.where((e) => e.dayOfWeek == 'Monday' && e.periodNumber == 1).toList();
      expect(mondayP1Entries.length, equals(1));
      expect(mondayP1Entries.first.id, equals('act_pre_existing'));
      expect(mondayP1Entries.first.isActivity, isTrue);

      // No other class was scheduled over Monday P1
      final mathOnMondayP1 = scheduled.where((e) => e.subjectId == 'sub_maths' && e.dayOfWeek == 'Monday' && e.periodNumber == 1);
      expect(mathOnMondayP1, isEmpty);
    });

    // -------------------------------------------------------------------------
    // TEST 12: Editing activity preserves activity type and fields
    // -------------------------------------------------------------------------
    test('12. Editing activity preserves activity type, activityName, and description', () {
      final originalActivity = TimetableEntry(
        id: 'act_100',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Wednesday',
        periodNumber: 3,
        sectionId: 'sec_a',
        subjectId: '',
        teacherId: '',
        roomId: 'room_101',
        entryType: 'activity',
        activityName: 'Original Workshop',
        description: 'Intro to Robotics',
      );

      final edited = originalActivity.copyWith(
        activityName: 'Advanced Robotics Workshop',
        description: 'Hands-on ROS development',
        roomId: 'room_102',
      );

      expect(edited.id, equals('act_100'));
      expect(edited.entryType, equals('activity'));
      expect(edited.isActivity, isTrue);
      expect(edited.activityName, equals('Advanced Robotics Workshop'));
      expect(edited.description, equals('Hands-on ROS development'));
      expect(edited.roomId, equals('room_102'));
      expect(edited.subjectId, isEmpty);
      expect(edited.teacherId, isEmpty);

      // Serialization test
      final json = edited.toJson();
      final revived = TimetableEntry.fromJson(json);
      expect(revived.isActivity, isTrue);
      expect(revived.entryType, equals('activity'));
      expect(revived.activityName, equals('Advanced Robotics Workshop'));
      expect(revived.description, equals('Hands-on ROS development'));
    });

    // -------------------------------------------------------------------------
    // TEST 13: Deleting an activity removes slot occupancy
    // -------------------------------------------------------------------------
    test('13. Deleting an activity frees the slot and allows scheduling a class', () {
      final activity = TimetableEntry(
        id: 'act_to_delete',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Thursday',
        periodNumber: 2,
        sectionId: 'sec_a',
        subjectId: '',
        teacherId: '',
        roomId: 'room_101',
        entryType: 'activity',
        activityName: 'Temporary Seminar',
      );

      // Slot is occupied initially
      var existingList = [activity];
      final classProposal = TimetableEntry(
        id: 'class_new',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Thursday',
        periodNumber: 2,
        sectionId: 'sec_a',
        subjectId: 'sub_maths',
        teacherId: 'staff_math',
        roomId: 'room_101',
        entryType: 'class',
      );

      var validation = ConflictValidator.validateProposedEntries(
        collegeId: collegeId,
        proposedEntries: [classProposal],
        existingEntries: existingList,
        sections: allSections,
        subjects: allSubjects,
        staffList: allStaff,
        rooms: allRooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );
      expect(validation.isValid, isFalse);

      // Delete the activity
      existingList = existingList.where((e) => e.id != activity.id).toList();

      validation = ConflictValidator.validateProposedEntries(
        collegeId: collegeId,
        proposedEntries: [classProposal],
        existingEntries: existingList,
        sections: allSections,
        subjects: allSubjects,
        staffList: allStaff,
        rooms: allRooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );
      expect(validation.isValid, isTrue);
    });

    // -------------------------------------------------------------------------
    // TEST 14: Parallel lab and theory classes remain unaffected alongside activities
    // -------------------------------------------------------------------------
    test('14. Parallel lab batches, theory classes, and activities coexist correctly', () {
      final subjectLab = Subject(
        id: 'sub_dsa_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'course_btech',
        semester: 3,
        subjectCode: 'CS302L',
        subjectName: 'Data Structures Lab',
        courseShortName: 'DS LAB',
        hoursPerWeek: 4,
        subjectType: 'Lab',
        requiredRoomType: 'Laboratory',
        consecutivePeriods: 2,
        assignedTeacherIds: ['staff_math', 'staff_physics'],
      );

      final labBatch1P1 = TimetableEntry(
        id: 'lab_b1_p1',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Tuesday',
        periodNumber: 1,
        sectionId: 'sec_a',
        subjectId: 'sub_dsa_lab',
        teacherId: 'staff_math',
        roomId: 'room_lab_1',
        batch: 'B1',
        entryType: 'class',
      );
      final labBatch1P2 = TimetableEntry(
        id: 'lab_b1_p2',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Tuesday',
        periodNumber: 2,
        sectionId: 'sec_a',
        subjectId: 'sub_dsa_lab',
        teacherId: 'staff_math',
        roomId: 'room_lab_1',
        batch: 'B1',
        entryType: 'class',
      );

      final labBatch2P1 = TimetableEntry(
        id: 'lab_b2_p1',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Tuesday',
        periodNumber: 1,
        sectionId: 'sec_a',
        subjectId: 'sub_dsa_lab',
        teacherId: 'staff_physics',
        roomId: 'room_lab_2',
        batch: 'B2',
        entryType: 'class',
      );
      final labBatch2P2 = TimetableEntry(
        id: 'lab_b2_p2',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Tuesday',
        periodNumber: 2,
        sectionId: 'sec_a',
        subjectId: 'sub_dsa_lab',
        teacherId: 'staff_physics',
        roomId: 'room_lab_2',
        batch: 'B2',
        entryType: 'class',
      );

      final activity = TimetableEntry(
        id: 'act_thursday',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Thursday',
        periodNumber: 1,
        sectionId: 'sec_a',
        subjectId: '',
        teacherId: '',
        roomId: 'room_101',
        entryType: 'activity',
        activityName: 'Industry Guest Lecture',
      );

      final theoryMath = TimetableEntry(
        id: 'math_friday',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Friday',
        periodNumber: 1,
        sectionId: 'sec_a',
        subjectId: 'sub_maths',
        teacherId: 'staff_math',
        roomId: 'room_101',
        entryType: 'class',
      );

      final entries = [
        labBatch1P1,
        labBatch1P2,
        labBatch2P1,
        labBatch2P2,
        activity,
        theoryMath,
      ];

      final staffLab1 = Staff(
        id: 'staff_math',
        collegeId: collegeId,
        employeeId: 'EMP_M',
        name: 'Prof. Gauss',
        email: 'gauss@college.edu',
        departmentId: 'dept_cs',
        subjectsCanTeach: ['sub_maths', 'sub_dsa_lab'],
      );
      final staffLab2 = Staff(
        id: 'staff_physics',
        collegeId: collegeId,
        employeeId: 'EMP_P',
        name: 'Prof. Newton',
        email: 'newton@college.edu',
        departmentId: 'dept_cs',
        subjectsCanTeach: ['sub_physics', 'sub_dsa_lab'],
      );

      final valResult = ConflictValidator.validateProposedEntries(
        collegeId: collegeId,
        proposedEntries: [theoryMath],
        existingEntries: [
          labBatch1P1,
          labBatch1P2,
          labBatch2P1,
          labBatch2P2,
          activity,
        ],
        sections: allSections,
        subjects: [...allSubjects, subjectLab],
        staffList: [staffLab1, staffLab2],
        rooms: allRooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(valResult.isValid, isTrue);
      expect(valResult.hardConflicts, isEmpty);

      // Verify that calculateProfessorWorkload excludes the activity
      final workload = calculateProfessorWorkload(
        teacher: testStaffMath,
        allSubjects: [...allSubjects, subjectLab],
        sectionMap: {'sec_a': testSectionA, 'sec_b': testSectionB},
        entries: entries,
        subjectMap: {'sub_maths': subjectMath, 'sub_dsa_lab': subjectLab},
      );
      expect(workload.scheduledTotal, equals(3)); // 2 lab periods + 1 theory
      expect(workload.scheduledLab, equals(2));
      expect(workload.scheduledTheory, equals(1));
    });
  });
}
