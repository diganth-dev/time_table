import 'dart:math' as math;
import '../../models/models.dart';

/// Returns sorted time slots including breaks and academic periods.
/// If [rawSlots] is empty, synthesizes dynamic slots from [college] schedule
/// settings and existing [entries] to ensure the matrix is always populated.
List<TimeSlot> getEffectiveTimeSlots(
  List<TimeSlot> rawSlots,
  College? college,
  List<TimetableEntry> entries,
) {
  if (rawSlots.isNotEmpty) {
    final list = List<TimeSlot>.from(rawSlots)..sort((a, b) => a.order.compareTo(b.order));
    final maxPeriodInSlots = list.where((s) => !s.isBreak).map((s) => s.periodNumber).fold<int>(0, math.max);
    final maxPeriodInEntries = entries.map((e) => e.periodNumber).fold<int>(0, math.max);
    if (maxPeriodInEntries > maxPeriodInSlots) {
      int lastOrder = list.isNotEmpty ? list.last.order : 0;
      for (int p = maxPeriodInSlots + 1; p <= maxPeriodInEntries; p++) {
        lastOrder++;
        list.add(TimeSlot(
          id: 'synth_p_$p',
          collegeId: college?.id ?? '',
          periodNumber: p,
          startTime: '',
          endTime: '',
          order: lastOrder,
          isBreak: false,
        ));
      }
    }
    return list;
  }

  // Synthesize from college settings & entries
  final numPeriods = math.max(
    college?.periodsPerDay ?? 6,
    entries.map((e) => e.periodNumber).fold<int>(0, math.max),
  ).clamp(1, 12);

  final duration = college?.periodDurationMinutes ?? 60;
  final startParts = (college?.startTime ?? '09:00').split(':');
  int startHour = int.tryParse(startParts[0]) ?? 9;
  int startMin = startParts.length > 1 ? (int.tryParse(startParts[1]) ?? 0) : 0;

  String formatTime(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  int currentTotalMin = startHour * 60 + startMin;
  final result = <TimeSlot>[];
  int order = 1;

  for (int p = 1; p <= numPeriods; p++) {
    // Check for morning break before period 3
    if (p == 3) {
      final bStart = college?.morningBreakStartTime ?? '11:00';
      final bEnd = college?.morningBreakEndTime ?? '11:15';
      result.add(TimeSlot(
        id: 'synth_break_morning',
        collegeId: college?.id ?? '',
        periodNumber: 0,
        startTime: bStart,
        endTime: bEnd,
        order: order++,
        isBreak: true,
        breakTitle: 'Tea Break',
      ));
    }

    // Check for lunch before midpoint or period 5
    final lunchInsertPeriod = (numPeriods >= 5) ? (numPeriods ~/ 2 + 1) : 4;
    if (p == lunchInsertPeriod) {
      final lStart = college?.lunchStartTime ?? '13:15';
      final lEnd = college?.lunchEndTime ?? '14:00';
      result.add(TimeSlot(
        id: 'synth_break_lunch',
        collegeId: college?.id ?? '',
        periodNumber: 0,
        startTime: lStart,
        endTime: lEnd,
        order: order++,
        isBreak: true,
        breakTitle: 'Lunch Break',
      ));
    }

    final pStartH = (currentTotalMin ~/ 60) % 24;
    final pStartM = currentTotalMin % 60;
    final pEndMin = currentTotalMin + duration;
    final pEndH = (pEndMin ~/ 60) % 24;
    final pEndM = pEndMin % 60;

    result.add(TimeSlot(
      id: 'synth_p_$p',
      collegeId: college?.id ?? '',
      periodNumber: p,
      startTime: formatTime(pStartH, pStartM),
      endTime: formatTime(pEndH, pEndM),
      order: order++,
      isBreak: false,
    ));

    currentTotalMin = pEndMin;
  }

  return result;
}

/// Workload summary metrics for a professor.
class ProfessorWorkloadSummary {
  final int requiredWorkload;
  final int scheduledTotal;
  final int scheduledTheory;
  final int scheduledLab;
  final int remaining;
  final bool isOverload;
  final int overload;

  const ProfessorWorkloadSummary({
    required this.requiredWorkload,
    required this.scheduledTotal,
    required this.scheduledTheory,
    required this.scheduledLab,
    required this.remaining,
    required this.isOverload,
    required this.overload,
  });
}

/// Calculates weekly required, scheduled, and remaining workload for [teacher].
ProfessorWorkloadSummary calculateProfessorWorkload({
  required Staff teacher,
  required List<Subject> allSubjects,
  required Map<String, Section> sectionMap,
  required List<TimetableEntry> entries,
  required Map<String, Subject> subjectMap,
}) {
  final teacherSubjs = allSubjects
      .where((s) => s.assignedTeacherIds.contains(teacher.id))
      .toList();

  int req = 0;
  if (teacherSubjs.isEmpty) {
    req = teacher.maxClassesPerWeek;
  } else {
    for (final s in teacherSubjs) {
      if (!s.isLab) {
        req += s.hoursPerWeek;
      } else {
        final sec = sectionMap[s.sectionId];
        final batchCount =
            (sec != null && sec.batches.isNotEmpty) ? sec.batches.length : 1;
        final dur = s.consecutivePeriods >= 2 ? s.consecutivePeriods : 2;
        if (batchCount <= 1) {
          req += s.hoursPerWeek;
        } else if (s.hoursPerWeek >= dur * batchCount) {
          req += s.hoursPerWeek;
        } else {
          req += dur * batchCount;
        }
      }
    }
  }

  final teacherEntries = entries
      .where((e) => !e.isActivity && e.teacherId == teacher.id && e.status != 'cancelled')
      .toList();

  int schedTheory = 0;
  int schedLab = 0;
  for (final e in teacherEntries) {
    final sub = subjectMap[e.subjectId];
    if (sub?.isLab == true || e.batch != null) {
      schedLab++;
    } else {
      schedTheory++;
    }
  }

  final schedTotal = schedTheory + schedLab;
  final rem = (req > schedTotal) ? (req - schedTotal) : 0;
  final isOver = schedTotal > req;
  final over = isOver ? (schedTotal - req) : 0;

  return ProfessorWorkloadSummary(
    requiredWorkload: req,
    scheduledTotal: schedTotal,
    scheduledTheory: schedTheory,
    scheduledLab: schedLab,
    remaining: rem,
    isOverload: isOver,
    overload: over,
  );
}

/// Represents a row in the "Course / Faculty / Venue Information" table
/// shared identically between the web ExportScreen and PDF exports.
class CourseFacultyVenueInfo {
  final Subject subject;
  final String courseCode;
  final String courseShortName;
  final String courseName;
  final String faculty;
  final String venue;

  const CourseFacultyVenueInfo({
    required this.subject,
    required this.courseCode,
    required this.courseShortName,
    required this.courseName,
    required this.faculty,
    required this.venue,
  });
}

/// Extracts the structured course, faculty, and venue rows for a section or overall schedule.
/// This is the SINGLE SOURCE OF TRUTH for the Course / Faculty / Venue Information table,
/// ensuring 100% data parity between the web ExportScreen and PDF exports.
List<CourseFacultyVenueInfo> extractCourseFacultyVenueInfo({
  required List<TimetableEntry> entries,
  required List<Subject> subjects,
  required Map<String, Staff> staffMap,
  required Map<String, Room> roomMap,
  required Section? targetSection,
  String viewMode = 'section',
}) {
  final entrySubjectIds = entries
      .where((e) => !e.isActivity && e.subjectId.isNotEmpty)
      .map((e) => e.subjectId)
      .toSet();
  List<Subject> displaySubjects = [];
  if (targetSection != null) {
    displaySubjects = subjects.where((s) {
      if (!s.active) return false;
      if (entrySubjectIds.contains(s.id)) return true;
      if (s.sectionId != null && s.sectionId!.isNotEmpty) {
        return s.sectionId == targetSection.id;
      }
      final deptMatch =
          s.departmentId.isEmpty || s.departmentId == targetSection.departmentId;
      final semMatch = s.semester == targetSection.semester;
      return deptMatch && semMatch;
    }).toList();
  }
  if (displaySubjects.isEmpty) {
    displaySubjects = subjects
        .where((s) => entrySubjectIds.contains(s.id))
        .toList();
  }
  if (displaySubjects.isEmpty &&
      subjects.isNotEmpty &&
      viewMode != 'section') {
    displaySubjects = subjects;
  }

  displaySubjects.sort((a, b) {
    if (a.subjectCode.isNotEmpty && b.subjectCode.isNotEmpty) {
      return a.subjectCode.compareTo(b.subjectCode);
    }
    return a.subjectName.compareTo(b.subjectName);
  });

  return displaySubjects.map((sub) {
    final subEntries = entries.where((e) => e.subjectId == sub.id).toList();

    // Resolve faculty names
    final teacherNames = subEntries
        .map((e) => staffMap[e.teacherId]?.name)
        .whereType<String>()
        .toSet()
        .toList();
    if (teacherNames.isEmpty && sub.assignedTeacherIds.isNotEmpty) {
      for (final tId in sub.assignedTeacherIds) {
        final name = staffMap[tId]?.name;
        if (name != null) teacherNames.add(name);
      }
    }
    final facultyStr = teacherNames.isNotEmpty ? teacherNames.join(', ') : '-';

    // Batch-specific lab venue information
    String venueStr;
    final batchEntries = subEntries.where((entry) => entry.batch != null).toList()
      ..sort((a, b) => a.batch!.compareTo(b.batch!));
    if (batchEntries.isNotEmpty) {
      venueStr = batchEntries
          .map(
            (entry) =>
                '${entry.batch}: ${roomMap[entry.roomId]?.roomNumber ?? 'Room'}',
          )
          .toSet()
          .join(', ');
    } else {
      final entryRooms = subEntries
          .map((e) => roomMap[e.roomId]?.roomNumber)
          .whereType<String>()
          .toSet()
          .toList();
      if (entryRooms.isNotEmpty) {
        venueStr = entryRooms.join(', ');
      } else {
        venueStr = sub.requiredRoomType.isNotEmpty
            ? sub.requiredRoomType
            : 'Classroom';
      }
    }

    final courseCodeStr =
        sub.subjectCode.trim().isNotEmpty ? sub.subjectCode.trim() : '-';
    final courseShortNameStr = sub.shortName.trim().isNotEmpty
        ? sub.shortName.trim()
        : (sub.subjectCode.isNotEmpty ? sub.subjectCode : sub.subjectName);

    return CourseFacultyVenueInfo(
      subject: sub,
      courseCode: courseCodeStr,
      courseShortName: courseShortNameStr,
      courseName: sub.subjectName,
      faculty: facultyStr,
      venue: venueStr,
    );
  }).toList();
}

