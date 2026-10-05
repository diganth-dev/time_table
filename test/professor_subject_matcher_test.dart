import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/core/utils/subject_matcher.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/services/conflict_validator.dart';

void main() {
  group('SubjectMatcher: Token & Word Matching Hierarchy', () {
    const actualSubjectName = 'Software Engineering & Project Management';
    const actualSubjectCode = 'CS301';
    const actualSubjectId = 'subj_sepm_001';

    test('1. Single meaningful word / token matching', () {
      // "software" -> "Software Engineering & Project Management" YES
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['software'],
          subjectName: actualSubjectName,
          subjectCode: actualSubjectCode,
        ),
        isTrue,
      );

      // "Software" (capitalized) YES
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['Software'],
          subjectName: actualSubjectName,
          subjectCode: actualSubjectCode,
        ),
        isTrue,
      );

      // "SOFTWARE" (uppercase) YES
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['SOFTWARE'],
          subjectName: actualSubjectName,
          subjectCode: actualSubjectCode,
        ),
        isTrue,
      );

      // "engineering" YES
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['engineering'],
          subjectName: actualSubjectName,
          subjectCode: actualSubjectCode,
        ),
        isTrue,
      );

      // "project" YES
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['project'],
          subjectName: actualSubjectName,
          subjectCode: actualSubjectCode,
        ),
        isTrue,
      );

      // "management" YES
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['management'],
          subjectName: actualSubjectName,
          subjectCode: actualSubjectCode,
        ),
        isTrue,
      );
    });

    test('2. Multi-token & phrase matching', () {
      // "software engineering" -> full subject YES
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['software engineering'],
          subjectName: actualSubjectName,
          subjectCode: actualSubjectCode,
        ),
        isTrue,
      );

      // "project management" -> full subject YES
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['project management'],
          subjectName: actualSubjectName,
          subjectCode: actualSubjectCode,
        ),
        isTrue,
      );

      // Full normalized subject with "and" vs "&"
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['Software Engineering and Project Management'],
          subjectName: actualSubjectName,
          subjectCode: actualSubjectCode,
        ),
        isTrue,
      );
    });

    test('3. Conservative spelling mistakes (Fuzzy Token Matching)', () {
      // "softwre" -> "software" YES
      final result1 = SubjectMatcher.evaluateStaffEligibility(
        subjectsCanTeach: ['softwre'],
        subjectName: actualSubjectName,
        subjectCode: actualSubjectCode,
      );
      expect(result1.isEligible, isTrue);
      expect(result1.tier, equals(MatchTier.fuzzyToken));

      // "enginering" -> "engineering" YES
      final result2 = SubjectMatcher.evaluateStaffEligibility(
        subjectsCanTeach: ['enginering'],
        subjectName: actualSubjectName,
        subjectCode: actualSubjectCode,
      );
      expect(result2.isEligible, isTrue);
      expect(result2.tier, equals(MatchTier.fuzzyToken));

      // "managment" -> "management" YES
      final result3 = SubjectMatcher.evaluateStaffEligibility(
        subjectsCanTeach: ['managment'],
        subjectName: actualSubjectName,
        subjectCode: actualSubjectCode,
      );
      expect(result3.isEligible, isTrue);
      expect(result3.tier, equals(MatchTier.fuzzyToken));
    });

    test('4. Professor input with multiple comma-separated subjects', () {
      final multiInput = ['software, operating systems'];

      // "Software Engineering & Project Management" -> ELIGIBLE because "software" matches
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: multiInput,
          subjectName: actualSubjectName,
          subjectCode: actualSubjectCode,
        ),
        isTrue,
      );

      // "Operating Systems" -> ELIGIBLE because "operating systems" matches
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: multiInput,
          subjectName: 'Operating Systems',
          subjectCode: 'CS302',
        ),
        isTrue,
      );

      // "Computer Networks" -> NOT ELIGIBLE
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: multiInput,
          subjectName: 'Computer Networks',
          subjectCode: 'CS303',
        ),
        isFalse,
      );
    });

    test('4b. Professor Kumaraswamy: "Operating systems, Software engineering and project management" vs "software"', () {
      final kumaCanTeach = ['Operating systems, Software engineering and project management'];

      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: kumaCanTeach,
          subjectName: 'software',
          subjectCode: '',
        ),
        isTrue,
        reason: 'Kumaraswamy must be eligible for "software" because "software" matches a meaningful token in "Software engineering and project management".',
      );
    });

    test('5. Hierarchy tiers: ID, Code, Full Name, Token, Acronym, Fuzzy', () {
      // Tier 1: ID Match
      final idMatch = SubjectMatcher.evaluateStaffEligibility(
        subjectsCanTeach: [actualSubjectId],
        subjectName: 'Different Name',
        subjectCode: 'DIFF101',
        subjectId: actualSubjectId,
      );
      expect(idMatch.isEligible, isTrue);
      expect(idMatch.tier, equals(MatchTier.subjectIdExact));

      // Tier 1: Code Match (with normalization of dashes/spaces)
      final codeMatch = SubjectMatcher.evaluateStaffEligibility(
        subjectsCanTeach: ['cs-301'],
        subjectName: 'Random Name',
        subjectCode: actualSubjectCode,
      );
      expect(codeMatch.isEligible, isTrue);
      expect(codeMatch.tier, equals(MatchTier.subjectCodeExact));

      // Tier 2: Full Normalized Name
      final nameMatch = SubjectMatcher.evaluateStaffEligibility(
        subjectsCanTeach: ['software   engineering  and project management'],
        subjectName: actualSubjectName,
        subjectCode: 'XYZ999',
      );
      expect(nameMatch.isEligible, isTrue);
      expect(nameMatch.tier, equals(MatchTier.fullNameExact));

      // Tier 4: Acronym Match (SEPM)
      final acronymMatch = SubjectMatcher.evaluateStaffEligibility(
        subjectsCanTeach: ['SEPM'],
        subjectName: actualSubjectName,
        subjectCode: 'XYZ999',
      );
      expect(acronymMatch.isEligible, isTrue);
      expect(acronymMatch.tier, equals(MatchTier.abbreviation));
    });

    test('6. FALSE POSITIVE PREVENTION: Unrestricted substring matching is NOT used', () {
      // "art" MUST NOT match an unrelated subject merely because letters occur inside another word
      // e.g. "Smart Systems" contains "art" inside "smart"
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['art'],
          subjectName: 'Smart Systems',
          subjectCode: 'EE401',
        ),
        isFalse,
        reason: '"art" should not match "Smart Systems" as a substring of "smart".',
      );

      // "art" MUST NOT match "Particle Physics"
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['art'],
          subjectName: 'Particle Physics',
          subjectCode: 'PH201',
        ),
        isFalse,
      );

      // "art" MUST NOT match "Earth Sciences"
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['art'],
          subjectName: 'Earth Sciences',
          subjectCode: 'ES101',
        ),
        isFalse,
      );

      // "art" MUST NOT match "Departmental Seminar"
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['art'],
          subjectName: 'Departmental Seminar',
          subjectCode: 'SEM01',
        ),
        isFalse,
      );

      // "art" MUST NOT match "Cartography"
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['art'],
          subjectName: 'Cartography',
          subjectCode: 'GEO301',
        ),
        isFalse,
      );

      // "art" MUST NOT match "Software Engineering & Project Management"
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['art'],
          subjectName: actualSubjectName,
          subjectCode: actualSubjectCode,
        ),
        isFalse,
      );

      // "net" MUST NOT match "Magnetics"
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['net'],
          subjectName: 'Applied Magnetics',
          subjectCode: 'PH301',
        ),
        isFalse,
      );

      // "computer" MUST NOT fuzzy match "compiler"
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['computer'],
          subjectName: 'Compiler Design',
          subjectCode: 'CS501',
        ),
        isFalse,
      );

      // "software" MUST NOT match "hardware"
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['software'],
          subjectName: 'Hardware Architecture',
          subjectCode: 'EC201',
        ),
        isFalse,
      );
    });

    test('7. Valid matches for Art subjects (Stemming and Exact Token)', () {
      // "art" matches "Fine Arts and Design" (singular/plural stem)
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['art'],
          subjectName: 'Fine Arts and Design',
          subjectCode: 'ART101',
        ),
        isTrue,
      );

      // "art" matches "Digital Art" (exact token)
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['art'],
          subjectName: 'Digital Art',
          subjectCode: 'ART102',
        ),
        isTrue,
      );
    });

    test('8. Stop words alone do NOT make a professor eligible', () {
      // Entering "and" should not match every subject with "and"
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['and'],
          subjectName: actualSubjectName,
          subjectCode: actualSubjectCode,
        ),
        isFalse,
      );

      // Entering "of" should not match "Theory of Computation"
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['of'],
          subjectName: 'Theory of Computation',
          subjectCode: 'CS401',
        ),
        isFalse,
      );
    });

    test('9. Universal eligibility for empty subjectsCanTeach (Rule 1)', () {
      // Empty list
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: [],
          subjectName: actualSubjectName,
          subjectCode: actualSubjectCode,
        ),
        isTrue,
      );

      // Blank entries
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['   ', ''],
          subjectName: actualSubjectName,
          subjectCode: actualSubjectCode,
        ),
        isTrue,
      );
    });
  });

  group('Staff Model & System Integration', () {
    const collegeId = 'col_apex_engineering';

    test('Staff.isEligibleForSubject integration with SubjectMatcher', () {
      final profSoftware = Staff(
        id: 'prof_soft',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        name: 'Dr. Soft',
        subjectsCanTeach: ['software'],
      );

      final profSpelling = Staff(
        id: 'prof_spell',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        name: 'Dr. Typo',
        subjectsCanTeach: ['softwre', 'enginering'],
      );

      final profUnrelated = Staff(
        id: 'prof_unrelated',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        name: 'Dr. Unrelated',
        subjectsCanTeach: ['art', 'chemistry'],
      );

      final profUniversal = Staff(
        id: 'prof_universal',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        name: 'Dr. Universal',
        subjectsCanTeach: [],
      );

      const targetName = 'Software Engineering & Project Management';
      const targetCode = 'CS301';

      expect(
        profSoftware.isEligibleForSubject(
          subjectName: targetName,
          subjectCode: targetCode,
        ),
        isTrue,
      );

      expect(
        profSpelling.isEligibleForSubject(
          subjectName: targetName,
          subjectCode: targetCode,
        ),
        isTrue,
      );

      expect(
        profUnrelated.isEligibleForSubject(
          subjectName: targetName,
          subjectCode: targetCode,
        ),
        isFalse,
      );

      expect(
        profUniversal.isEligibleForSubject(
          subjectName: targetName,
          subjectCode: targetCode,
        ),
        isTrue,
      );
    });

    test('ConflictValidator detects eligibility correctly', () {
      final subject = Subject(
        id: 'subj_sepm',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'cse',
        semester: 5,
        subjectName: 'Software Engineering & Project Management',
        subjectCode: 'CS301',
        assignedTeacherIds: ['prof_soft'],
      );

      final profEligible = Staff(
        id: 'prof_soft',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        name: 'Dr. Soft',
        subjectsCanTeach: ['software'],
        status: 'active',
      );

      final profIneligible = Staff(
        id: 'prof_ineligible',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        name: 'Dr. Chemistry',
        subjectsCanTeach: ['organic chemistry'],
        status: 'active',
      );

      final section = Section(
        id: 'sec_1',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'cse',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: '5A',
        studentCount: 40,
      );

      final room = Room(
        id: 'room_1',
        collegeId: collegeId,
        roomNumber: '101',
        capacity: 60,
      );

      final slot = TimeSlot(
        id: 'slot_1',
        collegeId: collegeId,
        startTime: '09:00',
        endTime: '10:00',
        periodNumber: 1,
        order: 1,
      );

      // Eligible professor has no unauthorizedTeacher conflict
      final entry1 = TimetableEntry(
        id: 'entry_1',
        versionId: 'v1',
        collegeId: collegeId,
        sectionId: section.id,
        subjectId: subject.id,
        teacherId: profEligible.id,
        roomId: room.id,
        dayOfWeek: 'Monday',
        periodNumber: 1,
      );

      final validation1 = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: [entry1],
        sections: [section],
        subjects: [subject],
        staffList: [profEligible],
        rooms: [room],
        timeSlots: [slot],
        availabilities: [],
      );

      expect(
        validation1.hardConflicts.any((c) => c.type == 'unauthorizedTeacher'),
        isFalse,
      );

      // Ineligible professor produces unauthorizedTeacher conflict
      final entry2 = TimetableEntry(
        id: 'entry_2',
        versionId: 'v1',
        collegeId: collegeId,
        sectionId: section.id,
        subjectId: subject.id,
        teacherId: profIneligible.id,
        roomId: room.id,
        dayOfWeek: 'Monday',
        periodNumber: 1,
      );

      final validation2 = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: [entry2],
        sections: [section],
        subjects: [subject],
        staffList: [profIneligible],
        rooms: [room],
        timeSlots: [slot],
        availabilities: [],
      );

      expect(
        validation2.hardConflicts.any((c) => c.type == 'unauthorizedTeacher'),
        isTrue,
      );
    });

    test('10 Acceptance Criteria: Global token matching across multiple subjects & spellings', () {
      // 1-5. Kumaraswamy with "software" vs "Software Engineering & Project Management"
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['software'],
          subjectName: 'Software Engineering & Project Management',
          subjectCode: 'CS301',
        ),
        isTrue,
      );

      // Reverse: Kumaraswamy with "Operating systems, Software engineering and project management" vs "software"
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['Operating systems, Software engineering and project management'],
          subjectName: 'software',
          subjectCode: 'CS301',
        ),
        isTrue,
      );

      // 6. "database" -> "Database Management Systems" => ELIGIBLE
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['database'],
          subjectName: 'Database Management Systems',
          subjectCode: 'CS302',
        ),
        isTrue,
      );

      // "management" -> "Database Management Systems" => ELIGIBLE
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['management'],
          subjectName: 'Database Management Systems',
          subjectCode: 'CS302',
        ),
        isTrue,
      );

      // 7. "computer" -> "Computer Networks" => ELIGIBLE
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['computer'],
          subjectName: 'Computer Networks',
          subjectCode: 'CS303',
        ),
        isTrue,
      );

      // "network" -> "Computer Networks" => ELIGIBLE
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['network'],
          subjectName: 'Computer Networks',
          subjectCode: 'CS303',
        ),
        isTrue,
      );

      // "programming" -> "Object Oriented Programming" => ELIGIBLE
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['programming'],
          subjectName: 'Object Oriented Programming',
          subjectCode: 'CS201',
        ),
        isTrue,
      );

      // "operating" -> "Operating Systems" => ELIGIBLE
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['operating'],
          subjectName: 'Operating Systems',
          subjectCode: 'CS304',
        ),
        isTrue,
      );

      // "systems" -> "Operating Systems" => ELIGIBLE
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['systems'],
          subjectName: 'Operating Systems',
          subjectCode: 'CS304',
        ),
        isTrue,
      );

      // 8. "software" -> "Computer Networks" => NOT ELIGIBLE
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['software'],
          subjectName: 'Computer Networks',
          subjectCode: 'CS303',
        ),
        isFalse,
      );

      // "computer" -> "Software Engineering & Project Management" => NOT ELIGIBLE
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['computer'],
          subjectName: 'Software Engineering & Project Management',
          subjectCode: 'CS301',
        ),
        isFalse,
      );

      // 9. "softwre" -> "Software Engineering & Project Management" => ELIGIBLE
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['softwre'],
          subjectName: 'Software Engineering & Project Management',
          subjectCode: 'CS301',
        ),
        isTrue,
      );

      // "enginering" -> "Software Engineering & Project Management" => ELIGIBLE
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['enginering'],
          subjectName: 'Software Engineering & Project Management',
          subjectCode: 'CS301',
        ),
        isTrue,
      );

      // "managment" -> "Software Engineering & Project Management" => ELIGIBLE
      expect(
        SubjectMatcher.isStaffEligible(
          subjectsCanTeach: ['managment'],
          subjectName: 'Software Engineering & Project Management',
          subjectCode: 'CS301',
        ),
        isTrue,
      );

      // Case insensitivity: software, Software, SOFTWARE
      for (final variant in ['software', 'Software', 'SOFTWARE']) {
        expect(
          SubjectMatcher.isStaffEligible(
            subjectsCanTeach: [variant],
            subjectName: 'Software Engineering & Project Management',
            subjectCode: 'CS301',
          ),
          isTrue,
        );
      }
    });
  });
}
