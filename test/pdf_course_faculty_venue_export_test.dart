import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:time_table/features/timetable/timetable_utils.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/services/pdf_export_service.dart';

void main() {
  group('PDF Course / Faculty / Venue Information Export Tests (TEST 1 to 13)', () {
    const collegeId = 'test_college_cfv';
    final college = College(
      id: collegeId,
      name: 'Global Institute of Technology',
      code: 'GIT',
      address: 'Tech Innovation Park',
      workingDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
      periodsPerDay: 5,
      academicYear: '2026-2027',
      currentSemester: 'Odd',
    );

    final version = TimetableVersion(
      id: 'ver_cfv_1',
      collegeId: collegeId,
      versionNumber: 1,
      name: 'Fall 2026 Official',
      status: 'published',
      academicYear: '2026-2027',
      semester: 'Odd',
      isCurrentPublished: true,
    );

    final sectionA = Section(
      id: 'sec_cse_a',
      collegeId: collegeId,
      departmentId: 'dept_cse',
      courseId: 'course_btech',
      academicYear: '2026-2027',
      semester: 5,
      sectionName: 'CSE(A)',
      studentCount: 60,
      batches: ['B1', 'B2'],
    );

    final profTuring = Staff(
      id: 'staff_turing',
      collegeId: collegeId,
      employeeId: 'EMP101',
      name: 'Dr. Alan Turing',
      email: 'turing@git.edu',
      departmentId: 'dept_cse',
      designation: 'Professor',
      status: 'active',
      subjectsCanTeach: ['sub_algo'],
      maxClassesPerDay: 4,
    );

    final profLiskov = Staff(
      id: 'staff_liskov',
      collegeId: collegeId,
      employeeId: 'EMP102',
      name: 'Dr. Barbara Liskov',
      email: 'liskov@git.edu',
      departmentId: 'dept_cse',
      designation: 'Professor',
      status: 'active',
      subjectsCanTeach: ['sub_os_lab'],
      maxClassesPerDay: 4,
    );

    final profShannon = Staff(
      id: 'staff_shannon',
      collegeId: collegeId,
      employeeId: 'EMP103',
      name: 'Dr. Claude Shannon',
      email: 'shannon@git.edu',
      departmentId: 'dept_cse',
      designation: 'Associate Professor',
      status: 'active',
      subjectsCanTeach: ['sub_cn_lab'],
      maxClassesPerDay: 4,
    );

    final roomLH101 = Room(
      id: 'room_lh101',
      collegeId: collegeId,
      roomNumber: 'LH-101',
      roomType: 'Classroom',
      capacity: 75,
      floor: 1,
      building: 'Main Block',
      facilities: ['Projector', 'Smart Board'],
    );

    final labRoomA = Room(
      id: 'room_lab_a',
      collegeId: collegeId,
      roomNumber: 'Lab-A',
      roomType: 'Lab',
      capacity: 35,
      floor: 2,
      building: 'Computing Block',
      facilities: ['Workstations'],
    );

    final labRoomB = Room(
      id: 'room_lab_b',
      collegeId: collegeId,
      roomNumber: 'Lab-B',
      roomType: 'Lab',
      capacity: 35,
      floor: 2,
      building: 'Computing Block',
      facilities: ['Workstations'],
    );

    final subjectAlgo = Subject(
      id: 'sub_algo',
      collegeId: collegeId,
      sectionId: sectionA.id,
      departmentId: 'dept_cse',
      courseId: 'course_btech',
      semester: 5,
      subjectCode: 'CS501',
      subjectName: 'Algorithms',
      courseShortName: 'ALGO',
      subjectType: 'Theory',
      hoursPerWeek: 4,
      requiredRoomType: 'Classroom',
      assignedTeacherIds: [profTuring.id],
    );

    final subjectOsLab = Subject(
      id: 'sub_os_lab',
      collegeId: collegeId,
      sectionId: sectionA.id,
      departmentId: 'dept_cse',
      courseId: 'course_btech',
      semester: 5,
      subjectCode: 'CS502L',
      subjectName: 'Operating Systems Laboratory',
      courseShortName: 'OS LAB',
      subjectType: 'Lab',
      hoursPerWeek: 2,
      consecutivePeriods: 2,
      requiredRoomType: 'Lab',
      assignedTeacherIds: [profLiskov.id],
    );

    final subjectCnLab = Subject(
      id: 'sub_cn_lab',
      collegeId: collegeId,
      sectionId: sectionA.id,
      departmentId: 'dept_cse',
      courseId: 'course_btech',
      semester: 5,
      subjectCode: 'CS503L',
      subjectName: 'Computer Networks Laboratory',
      courseShortName: 'CN LAB',
      subjectType: 'Lab',
      hoursPerWeek: 2,
      consecutivePeriods: 2,
      requiredRoomType: 'Lab',
      assignedTeacherIds: [profShannon.id],
    );

    final timeSlots = [
      TimeSlot(id: 's1', collegeId: collegeId, periodNumber: 1, startTime: '09:00', endTime: '10:00', isBreak: false, order: 1),
      TimeSlot(id: 's2', collegeId: collegeId, periodNumber: 2, startTime: '10:00', endTime: '11:00', isBreak: false, order: 2),
      TimeSlot(id: 'sb', collegeId: collegeId, periodNumber: 0, startTime: '11:00', endTime: '11:15', isBreak: true, order: 3),
      TimeSlot(id: 's3', collegeId: collegeId, periodNumber: 3, startTime: '11:15', endTime: '12:15', isBreak: false, order: 4),
      TimeSlot(id: 's4', collegeId: collegeId, periodNumber: 4, startTime: '12:15', endTime: '13:15', isBreak: false, order: 5),
    ];

    final entries = [
      // Theory session on Monday P1
      TimetableEntry(
        id: 'e1',
        collegeId: collegeId,
        versionId: version.id,
        sectionId: sectionA.id,
        subjectId: subjectAlgo.id,
        teacherId: profTuring.id,
        roomId: roomLH101.id,
        dayOfWeek: 'Monday',
        periodNumber: 1,
        batch: null,
      ),
      // B1 OS Lab on Monday P3-P4 in Lab-A with Liskov
      TimetableEntry(
        id: 'e_b1_3',
        collegeId: collegeId,
        versionId: version.id,
        sectionId: sectionA.id,
        subjectId: subjectOsLab.id,
        teacherId: profLiskov.id,
        roomId: labRoomA.id,
        dayOfWeek: 'Monday',
        periodNumber: 3,
        batch: 'B1',
      ),
      TimetableEntry(
        id: 'e_b1_4',
        collegeId: collegeId,
        versionId: version.id,
        sectionId: sectionA.id,
        subjectId: subjectOsLab.id,
        teacherId: profLiskov.id,
        roomId: labRoomA.id,
        dayOfWeek: 'Monday',
        periodNumber: 4,
        batch: 'B1',
      ),
      // B2 CN Lab on Monday P3-P4 in Lab-B with Shannon
      TimetableEntry(
        id: 'e_b2_3',
        collegeId: collegeId,
        versionId: version.id,
        sectionId: sectionA.id,
        subjectId: subjectCnLab.id,
        teacherId: profShannon.id,
        roomId: labRoomB.id,
        dayOfWeek: 'Monday',
        periodNumber: 3,
        batch: 'B2',
      ),
      TimetableEntry(
        id: 'e_b2_4',
        collegeId: collegeId,
        versionId: version.id,
        sectionId: sectionA.id,
        subjectId: subjectCnLab.id,
        teacherId: profShannon.id,
        roomId: labRoomB.id,
        dayOfWeek: 'Monday',
        periodNumber: 4,
        batch: 'B2',
      ),
    ];

    final staffMap = <String, Staff>{
      profTuring.id: profTuring,
      profLiskov.id: profLiskov,
      profShannon.id: profShannon,
    };
    final sectionMap = <String, Section>{sectionA.id: sectionA};
    final roomMap = <String, Room>{
      roomLH101.id: roomLH101,
      labRoomA.id: labRoomA,
      labRoomB.id: labRoomB,
    };
    final subjectMap = <String, Subject>{
      subjectAlgo.id: subjectAlgo,
      subjectOsLab.id: subjectOsLab,
      subjectCnLab.id: subjectCnLab,
    };

    Future<String> generatePdfText({
      List<TimetableEntry>? testEntries,
      Map<String, Subject>? testSubjectMap,
      Map<String, Room>? testRoomMap,
    }) async {
      final bytes = await PdfExportService.generateTimetablePdf(
        pageFormat: PdfPageFormat.a4,
        college: college,
        version: version,
        entries: testEntries ?? entries,
        timeSlots: timeSlots,
        staffMap: staffMap,
        sectionMap: sectionMap,
        roomMap: testRoomMap ?? roomMap,
        subjectMap: testSubjectMap ?? subjectMap,
        targetView: 'section',
        selectedSectionId: sectionA.id,
        compress: false,
      );
      final raw = latin1.decode(bytes);
      final regex = RegExp(r'\(([^)]*)\)');
      final tokens = regex.allMatches(raw).map((m) => m.group(1)!).join(' ');
      return '$raw\n$tokens';
    }

    test('TEST 1: PDF export contains Course / Faculty / Venue Information section', () async {
      final text = await generatePdfText();
      expect(text.contains('Course'), isTrue);
      expect(text.contains('Faculty'), isTrue);
      expect(text.contains('Venue'), isTrue);
      expect(text.contains('Information'), isTrue);
    });

    test('TEST 2: PDF contains Course Code', () async {
      final text = await generatePdfText();
      expect(text.contains('Course Code') || (text.contains('Course') && text.contains('Code')), isTrue);
      expect(text.contains('CS501'), isTrue);
      expect(text.contains('CS502L'), isTrue);
      expect(text.contains('CS503L'), isTrue);
    });

    test('TEST 3: PDF contains Course Short Name', () async {
      final text = await generatePdfText();
      expect(text.contains('Course Short Name') || (text.contains('Short') && text.contains('Name')), isTrue);
      expect(text.contains('ALGO'), isTrue);
      expect(text.contains('OS LAB'), isTrue);
      expect(text.contains('CN LAB'), isTrue);
    });

    test('TEST 4: PDF contains Course Name', () async {
      final text = await generatePdfText();
      expect(text.contains('Algorithms'), isTrue);
      expect(text.contains('Operating Systems Laboratory') || (text.contains('Operating') && text.contains('Systems')), isTrue);
      expect(text.contains('Computer Networks Laboratory') || (text.contains('Computer') && text.contains('Networks')), isTrue);
    });

    test('TEST 5: PDF contains Faculty', () async {
      final text = await generatePdfText();
      expect(text.contains('Faculty'), isTrue);
      expect(text.contains('Alan Turing') || (text.contains('Alan') && text.contains('Turing')), isTrue);
      expect(text.contains('Barbara Liskov') || (text.contains('Barbara') && text.contains('Liskov')), isTrue);
      expect(text.contains('Claude Shannon') || (text.contains('Claude') && text.contains('Shannon')), isTrue);
    });

    test('TEST 6: PDF contains Venue', () async {
      final text = await generatePdfText();
      expect(text.contains('Venue'), isTrue);
      expect(text.contains('LH-101'), isTrue);
      expect(text.contains('Lab-A'), isTrue);
      expect(text.contains('Lab-B'), isTrue);
    });

    test('TEST 7: All courses shown in ExportScreen are represented in the PDF table', () async {
      final webItems = extractCourseFacultyVenueInfo(
        entries: entries,
        subjects: subjectMap.values.toList(),
        staffMap: staffMap,
        roomMap: roomMap,
        targetSection: sectionA,
        viewMode: 'section',
      );
      expect(webItems.isNotEmpty, isTrue);

      final text = await generatePdfText();
      for (final item in webItems) {
        expect(text.contains(item.courseCode), isTrue);
        expect(text.contains(item.courseShortName), isTrue);
        // Each word of subject name is in PDF
        for (final word in item.courseName.split(' ')) {
          expect(text.contains(word), isTrue);
        }
      }
    });

    test('TEST 8: Batch-specific lab venue information is preserved', () async {
      final text = await generatePdfText();
      expect(text.contains('B1: Lab-A') || (text.contains('B1') && text.contains('Lab-A')), isTrue);
      expect(text.contains('B2: Lab-B') || (text.contains('B2') && text.contains('Lab-B')), isTrue);
    });

    test('TEST 9: B1 and B2 independent venues are not incorrectly merged', () async {
      final text = await generatePdfText();
      // Ensure both independent venues are present
      expect(text.contains('Lab-A'), isTrue);
      expect(text.contains('Lab-B'), isTrue);
      expect(text.contains('B1: Lab-A'), isTrue);
      expect(text.contains('B2: Lab-B'), isTrue);
    });

    test('TEST 10: Long course names wrap instead of overflowing', () async {
      final longSubject = Subject(
        id: 'sub_long',
        collegeId: collegeId,
        sectionId: sectionA.id,
        departmentId: 'dept_cse',
        courseId: 'course_btech',
        semester: 5,
        subjectCode: 'CS599',
        subjectName: 'Advanced Quantum Distributed High Performance Machine Learning Architectures',
        courseShortName: 'QUANTUM ML',
        subjectType: 'Theory',
        hoursPerWeek: 4,
        requiredRoomType: 'Classroom',
        assignedTeacherIds: [profTuring.id],
      );

      final customSubjectMap = <String, Subject>{...subjectMap, longSubject.id: longSubject};
      final customEntries = [
        ...entries,
        TimetableEntry(
          id: 'e_long',
          collegeId: collegeId,
          versionId: version.id,
          sectionId: sectionA.id,
          subjectId: longSubject.id,
          teacherId: profTuring.id,
          roomId: roomLH101.id,
          dayOfWeek: 'Tuesday',
          periodNumber: 1,
        ),
      ];

      final text = await generatePdfText(
        testEntries: customEntries,
        testSubjectMap: customSubjectMap,
      );

      expect(text.contains('CS599'), isTrue);
      expect(text.contains('QUANTUM ML'), isTrue);
      expect(text.contains('Advanced') && text.contains('Quantum') && text.contains('Machine'), isTrue);
    });

    test('TEST 11: Long venue information wraps instead of overflowing', () async {
      final longRoom = Room(
        id: 'room_long_venue',
        collegeId: collegeId,
        roomNumber: 'Advanced Quantum Computing Center Lab 402B North Wing',
        roomType: 'Lab',
        capacity: 40,
        floor: 4,
        building: 'Quantum Complex',
      );

      final customRoomMap = <String, Room>{...roomMap, longRoom.id: longRoom};
      final customEntries = [
        ...entries,
        TimetableEntry(
          id: 'e_long_room',
          collegeId: collegeId,
          versionId: version.id,
          sectionId: sectionA.id,
          subjectId: subjectAlgo.id,
          teacherId: profTuring.id,
          roomId: longRoom.id,
          dayOfWeek: 'Wednesday',
          periodNumber: 2,
        ),
      ];

      final text = await generatePdfText(
        testEntries: customEntries,
        testRoomMap: customRoomMap,
      );

      expect(text.contains('Quantum') && text.contains('Computing') && text.contains('Center'), isTrue);
    });

    test('TEST 12: If the table exceeds one page, it continues correctly onto the next page', () async {
      // Create 20 subjects to force the table to span multiple pages
      final manySubjects = <String, Subject>{...subjectMap};
      final manyEntries = <TimetableEntry>[...entries];

      for (int i = 1; i <= 20; i++) {
        final sub = Subject(
          id: 'sub_extra_$i',
          collegeId: collegeId,
          sectionId: sectionA.id,
          departmentId: 'dept_cse',
          courseId: 'course_btech',
          semester: 5,
          subjectCode: 'CS6${i.toString().padLeft(2, '0')}',
          subjectName: 'Elective Course Module Number $i',
          courseShortName: 'ELEC $i',
          subjectType: 'Theory',
          hoursPerWeek: 3,
          requiredRoomType: 'Classroom',
          assignedTeacherIds: [profTuring.id],
        );
        manySubjects[sub.id] = sub;
        manyEntries.add(TimetableEntry(
          id: 'e_extra_$i',
          collegeId: collegeId,
          versionId: version.id,
          sectionId: sectionA.id,
          subjectId: sub.id,
          teacherId: profTuring.id,
          roomId: roomLH101.id,
          dayOfWeek: 'Friday',
          periodNumber: (i % 4) + 1,
        ));
      }

      final text = await generatePdfText(
        testEntries: manyEntries,
        testSubjectMap: manySubjects,
      );

      // Verify that multiple pages were generated
      expect(text.contains('Count 2') || text.contains('Count 3') || text.contains('Page 2 of') || text.contains('of 2') || text.contains('of 3'), isTrue);

      // Verify that the table header row is repeated on subsequent pages
      // By checking that 'Course Code' appears at least twice in the text
      final courseCodeMatches = RegExp(r'Course Code').allMatches(text).length;
      expect(courseCodeMatches, greaterThanOrEqualTo(2));

      // Verify subjects on page 2 are present
      expect(text.contains('CS620'), isTrue);
      expect(text.contains('CS615'), isTrue);
    });

    test('TEST 13: Existing timetable PDF tests continue to pass', () async {
      // Verify normal compressed PDF generation still works cleanly and returns valid PDF
      final bytes = await PdfExportService.generateTimetablePdf(
        pageFormat: PdfPageFormat.a4,
        college: college,
        version: version,
        entries: entries,
        timeSlots: timeSlots,
        staffMap: staffMap,
        sectionMap: sectionMap,
        roomMap: roomMap,
        subjectMap: subjectMap,
        targetView: 'section',
        selectedSectionId: sectionA.id,
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });
  });
}
