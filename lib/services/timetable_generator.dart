import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'conflict_validator.dart';

class GenerationResult {
  final bool isSuccess;
  final String versionId;
  final List<TimetableEntry> entries;
  final List<TimetableEntry> newlyScheduledEntries;
  final int totalClassesScheduled;
  final int teachersUsed;
  final int roomsUsed;
  final int sectionsScheduled;
  final int generationTimeMs;
  final List<ConflictItem> conflicts;
  final String summaryMessage;
  final String? targetSectionId;

  GenerationResult({
    required this.isSuccess,
    required this.versionId,
    required this.entries,
    List<TimetableEntry>? newlyScheduledEntries,
    required this.totalClassesScheduled,
    required this.teachersUsed,
    required this.roomsUsed,
    required this.sectionsScheduled,
    required this.generationTimeMs,
    required this.conflicts,
    required this.summaryMessage,
    this.targetSectionId,
  }) : newlyScheduledEntries = newlyScheduledEntries ?? entries;
}

class _ClassSessionRequest {
  final Section section;
  final Subject subject;
  final String? batch; // null for whole section, or individual batch string (e.g. 'B1', 'B2', 'Batch-Alpha')
  final int sessionIndex; // 0, 1, 2...
  final int durationPeriods; // 1 for theory, 2 for lab block
  final int labRoundIndex; // round index for parallel cross-batch rotation

  _ClassSessionRequest({
    required this.section,
    required this.subject,
    this.batch,
    required this.sessionIndex,
    this.durationPeriods = 1,
    this.labRoundIndex = 0,
  });

  bool get isLab => subject.isLab || batch != null;
  List<String> get batchNames => batch != null ? [batch!] : section.batches;
  String get id => batch != null
      ? '${section.id}_${subject.id}_${batch}_$sessionIndex'
      : '${section.id}_${subject.id}_$sessionIndex';
}

class TimetableGenerator {
  static const _uuid = Uuid();

  static Subject? findSubject({
    required String subjectId,
    required Map<String, Subject> subjectMap,
    required List<Subject> subjects,
  }) {
    if (subjectMap.containsKey(subjectId)) {
      return subjectMap[subjectId];
    }
    final norm = subjectId.trim().toLowerCase();
    final byCode = subjects.where((s) =>
        s.subjectCode.isNotEmpty &&
        s.subjectCode.trim().toLowerCase() == norm).firstOrNull;
    if (byCode != null) return byCode;
    return subjects.where((s) =>
        s.subjectName.isNotEmpty &&
        s.subjectName.trim().toLowerCase() == norm).firstOrNull;
  }

  static String resolveSubjectKey({
    required String subjectId,
    required Map<String, Subject> subjectMap,
    required List<Subject> subjects,
  }) {
    final s = findSubject(
      subjectId: subjectId,
      subjectMap: subjectMap,
      subjects: subjects,
    );
    if (s != null) {
      if (s.id.isNotEmpty) return s.id;
      if (s.subjectCode.isNotEmpty) return s.subjectCode.trim().toLowerCase();
      return s.subjectName.trim().toLowerCase();
    }
    return subjectId.trim().toLowerCase();
  }

  static bool isLabEntry({
    required TimetableEntry entry,
    required Map<String, Subject> subjectMap,
    required List<Subject> subjects,
  }) {
    if (entry.batch != null && entry.batch!.isNotEmpty) return true;
    final s = findSubject(
      subjectId: entry.subjectId,
      subjectMap: subjectMap,
      subjects: subjects,
    );
    if (s != null) return s.isLab;
    final norm = entry.subjectId.trim().toLowerCase();
    return norm.contains('lab');
  }

  static bool matchesFacility(Room room, String requiredFacility, {Subject? subject}) {
    final req = requiredFacility.trim().toLowerCase();
    final rType = room.roomType.trim().toLowerCase();

    // Normal classroom must never satisfy a lab requirement unless subject allows classroom
    if (subject != null && subject.isLab && !subject.allowsClassroom) {
      if (rType == 'classroom' || rType.isEmpty) {
        return false;
      }
    }

    // Explicit room-level compatible subjects/capabilities take priority
    if (room.compatibleSubjects.isNotEmpty) {
      final compLower = room.compatibleSubjects.map((s) => s.trim().toLowerCase()).toSet();
      if (subject != null) {
        final subName = subject.subjectName.trim().toLowerCase();
        final subCode = subject.subjectCode.trim().toLowerCase();
        final shortName = subject.shortName.trim().toLowerCase();
        if (compLower.contains(subName) ||
            compLower.contains(subCode) ||
            compLower.contains(shortName)) {
          return true;
        }
      }
      if (req.isNotEmpty && compLower.contains(req)) {
        return true;
      }
      return false;
    }

    if (req.isEmpty || req == 'classroom') {
      if (subject != null && subject.isLab) {
        return rType.contains('lab') ||
            room.facilities.any((f) => f.trim().toLowerCase().contains('lab'));
      }
      return true;
    }

    // Direct roomType match
    if (rType == req) return true;

    // Check facilities list
    final facLower = room.facilities.map((f) => f.trim().toLowerCase()).toSet();
    if (facLower.contains(req)) return true;

    if (subject != null) {
      final subName = subject.subjectName.trim().toLowerCase();
      final subCode = subject.subjectCode.trim().toLowerCase();
      final shortName = subject.shortName.trim().toLowerCase();
      if (facLower.contains(subName) ||
          facLower.contains(subCode) ||
          facLower.contains(shortName)) {
        return true;
      }
    }

    return false;
  }

  static bool isRoomEligibleForSubject({
    required Room room,
    required Subject subject,
    Section? section,
  }) {
    if (!room.active || room.isUnderMaintenance) {
      return false;
    }

    if (subject.isLab) {
      final rType = room.roomType.trim().toLowerCase();
      final isClassroom = rType == 'classroom' || rType.isEmpty;

      if (subject.allowsClassroom) {
        if (isClassroom) {
          // If section specifies eligible classrooms, restrict to those
          if (section != null && section.eligibleClassroomIds.isNotEmpty) {
            return section.eligibleClassroomIds.contains(room.id);
          }
          return true;
        }

        // Room is a physical lab/specialized room.
        // If subject only allows classroom, physical labs are not allowed.
        final physicalLabIds = subject.eligibleLabIds
            .where((id) =>
                id.toLowerCase() != 'class' && id.toLowerCase() != 'classroom')
            .toList();
        if (physicalLabIds.isNotEmpty) {
          if (!physicalLabIds.contains(room.id)) {
            return false;
          }
          return matchesFacility(room, subject.requiredRoomType, subject: subject);
        }
        return false;
      }

      // Normal lab: classroom must never satisfy a lab requirement
      if (isClassroom) {
        return false;
      }

      // If subject has specific referenced global labs configured, enforce reference constraint
      if (subject.eligibleLabIds.isNotEmpty) {
        if (!subject.eligibleLabIds.contains(room.id)) {
          return false;
        }
      }

      return matchesFacility(room, subject.requiredRoomType, subject: subject);
    } else {
      // Theory subject: check section-level classroom eligibility if configured
      if (section != null && section.eligibleClassroomIds.isNotEmpty) {
        if (!section.eligibleClassroomIds.contains(room.id)) {
          return false;
        }
      }
      return matchesFacility(room, subject.requiredRoomType, subject: subject);
    }
  }

  /// Executes constraint-based timetable generation
  static GenerationResult generate({
    required String collegeId,
    required List<Section> sections,
    required List<Subject> subjects,
    required List<Staff> staffList,
    required List<Room> rooms,
    required List<TimeSlot> timeSlots,
    required List<TeacherAvailability> availabilities,
    List<String>? workingDays,
    String? customVersionId,
    String? targetSectionId,
    List<TimetableEntry>? existingEntries,
  }) {
    final stopwatch = Stopwatch()..start();
    final versionId =
        customVersionId ?? 'ver_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Identify valid academic periods (exclude break/lunch)
    final academicSlots = timeSlots.where((t) => !t.isBreak).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final orderedAllSlots = [...timeSlots]
      ..sort((a, b) => a.order.compareTo(b.order));

    final validPeriodNumbers =
        academicSlots.map((s) => s.periodNumber).toSet().toList()..sort();
    final days =
        workingDays ?? ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

    if (academicSlots.isEmpty || days.isEmpty) {
      stopwatch.stop();
      return GenerationResult(
        isSuccess: false,
        versionId: versionId,
        entries: existingEntries ?? [],
        totalClassesScheduled: 0,
        teachersUsed: 0,
        roomsUsed: 0,
        sectionsScheduled: 0,
        generationTimeMs: stopwatch.elapsedMilliseconds,
        conflicts: [
          ConflictItem(
            id: 'gen_no_periods_$collegeId',
            collegeId: collegeId,
            type: 'incompleteHours',
            title: 'No Academic Periods Configured',
            description:
                'No active academic periods or working days found in college configuration.',
            suggestion:
                'Configure periods and working days in College Settings.',
          ),
        ],
        summaryMessage:
            'Timetable could not be generated: missing academic periods.',
        targetSectionId: targetSectionId,
      );
    }

    // 2. Build active rooms filter
    final activeRooms = rooms
        .where((r) => r.active && !r.isUnderMaintenance)
        .toList();

    // Identify target sections to schedule
    final targetSections = targetSectionId != null
        ? sections.where((s) => s.id == targetSectionId && s.active).toList()
        : sections.where((s) => s.active).toList();

    if (targetSectionId != null && targetSections.isEmpty) {
      stopwatch.stop();
      return GenerationResult(
        isSuccess: false,
        versionId: versionId,
        entries: existingEntries ?? [],
        totalClassesScheduled: 0,
        teachersUsed: 0,
        roomsUsed: 0,
        sectionsScheduled: 0,
        generationTimeMs: stopwatch.elapsedMilliseconds,
        conflicts: [
          ConflictItem(
            id: 'gen_section_not_found_${targetSectionId}_$collegeId',
            collegeId: collegeId,
            type: 'sectionNotFound',
            title: 'Selected Section Inactive or Missing',
            description:
                'Selected section ID "$targetSectionId" could not be found or is inactive.',
            suggestion: 'Verify class section status in Sections & Subjects.',
          ),
        ],
        summaryMessage: 'Selected section could not be found or is inactive.',
        targetSectionId: targetSectionId,
      );
    }

    // 3. Pre-flight Validation: Check target section subjects for assigned and eligible professor
    final preflightConflicts = <ConflictItem>[];
    for (final sec in targetSections) {
      if (!sec.active) continue;

      final secSubjs = subjects.where((sub) {
        if (!sub.active) return false;
        if (sub.sectionId != null && sub.sectionId!.isNotEmpty) {
          return sub.sectionId == sec.id;
        }
        final deptMatch =
            sub.departmentId.isEmpty || sub.departmentId == sec.departmentId;
        final semMatch = sub.semester == sec.semester;
        return deptMatch && semMatch;
      }).toList();

      for (final subj in secSubjs) {
        if (subj.assignedTeacherIds.isEmpty) {
          preflightConflicts.add(
            ConflictItem(
              id: 'preflight_unassigned_${sec.id}_${subj.id}',
              collegeId: collegeId,
              type: 'unassignedTeacher',
              title: 'Subject Missing Assigned Professor',
              description:
                  'Subject "${subj.subjectName}" (${subj.subjectCode}) in Section "${sec.displayName}" has no assigned professor. Every subject must have an assigned professor before timetable generation.',
              subjectId: subj.id,
              sectionId: sec.id,
              suggestion:
                  'Assign an eligible professor in Sections & Subjects before generating.',
            ),
          );
        } else {
          final assignedStaff = staffList
              .where((s) => s.active && subj.assignedTeacherIds.contains(s.id))
              .toList();
          if (assignedStaff.isEmpty) {
            preflightConflicts.add(
              ConflictItem(
                id: 'preflight_unauthorized_${sec.id}_${subj.id}',
                collegeId: collegeId,
                type: 'unauthorizedTeacher',
                title: 'Assigned Professor Not Available',
                description:
                    'The professor assigned to "${subj.subjectName}" in Section "${sec.displayName}" does not exist or is inactive.',
                subjectId: subj.id,
                sectionId: sec.id,
                suggestion: 'Reassign an active professor to this subject.',
              ),
            );
          } else {
            final eligible = assignedStaff
                .where(
                  (s) => s.isEligibleForSubject(
                    subjectName: subj.subjectName,
                    subjectCode: subj.subjectCode,
                    courseShortName: subj.courseShortName,
                    subjectId: subj.id,
                  ),
                )
                .toList();

            if (eligible.isEmpty) {
              preflightConflicts.add(
                ConflictItem(
                  id: 'preflight_ineligible_${sec.id}_${subj.id}_${assignedStaff.first.id}',
                  collegeId: collegeId,
                  type: 'ineligibleTeacher',
                  title: 'Ineligible Professor Assigned',
                  description:
                      'Professor ${assignedStaff.first.name} is not eligible to teach "${subj.subjectName}" (${subj.subjectCode}) based on their configured "Can Teach" list.',
                  subjectId: subj.id,
                  sectionId: sec.id,
                  suggestion:
                      'Update ${assignedStaff.first.name}\'s "Subjects they can teach" or assign an eligible professor.',
                ),
              );
            }
          }
        }
        if (subj.isLab &&
            subj.consecutivePeriods > 1 &&
            subj.hoursPerWeek % subj.consecutivePeriods != 0) {
          preflightConflicts.add(
            ConflictItem(
              id: 'preflight_lab_duration_${sec.id}_${subj.id}',
              collegeId: collegeId,
              type: 'invalidLabDuration',
              severity: 'hard',
              title: 'Lab Hours Do Not Fit Complete Blocks',
              description:
                  '${subj.subjectName} requires ${subj.consecutivePeriods}-period consecutive blocks, but ${subj.hoursPerWeek} weekly periods leave a partial block.',
              subjectId: subj.id,
              sectionId: sec.id,
              suggestion:
                  'Set weekly lab hours to a multiple of the configured consecutive period duration.',
            ),
          );
        }
        if (subj.assignedTeacherIds.isNotEmpty && !subj.isLab) {
          final reqSessions = subj.consecutivePeriods > 1
              ? (subj.hoursPerWeek / subj.consecutivePeriods).ceil()
              : subj.hoursPerWeek;
          if (reqSessions > days.length) {
            preflightConflicts.add(
              ConflictItem(
                id: 'preflight_subject_repetition_${sec.id}_${subj.id}',
                collegeId: collegeId,
                type: 'sameDaySubjectConflict',
                severity: 'hard',
                title: 'Infeasible Subject Weekly Distribution',
                description:
                    '${subj.subjectName} requires ${subj.hoursPerWeek} weekly periods, but only ${days.length} working days are available (${days.join(", ")}). A theory subject may have at most one session per day.',
                subjectId: subj.id,
                sectionId: sec.id,
                suggestion:
                    'Increase active working days in College Settings, reduce weekly subject hours, or configure multi-period blocks if applicable.',
              ),
            );
          }
        }
      }
    }

    if (preflightConflicts.isNotEmpty) {
      stopwatch.stop();
      return GenerationResult(
        isSuccess: false,
        versionId: versionId,
        entries: existingEntries ?? [],
        totalClassesScheduled: 0,
        teachersUsed: 0,
        roomsUsed: 0,
        sectionsScheduled: 0,
        generationTimeMs: stopwatch.elapsedMilliseconds,
        conflicts: preflightConflicts,
        summaryMessage:
            preflightConflicts.any(
              (conflict) =>
                  conflict.type == 'invalidLabDuration' ||
                  conflict.type == 'sameDaySubjectConflict',
            )
            ? 'Timetable cannot be generated with the current constraints: ${preflightConflicts.length} input issue(s) detected.'
            : 'Timetable cannot be generated with the current constraints: ${preflightConflicts.length} professor assignment or eligibility issue(s) detected.',
        targetSectionId: targetSectionId,
      );
    }

    // 4. Build Session Requests for target section(s)
    final sessionRequests = <_ClassSessionRequest>[];
    final sectionSubjects = <String, List<Subject>>{};

    for (final sec in targetSections) {
      if (!sec.active) continue;

      // Find matching subjects for this section (prioritizing direct sectionId binding)
      final secSubjs = subjects.where((sub) {
        if (!sub.active) return false;
        if (sub.sectionId != null && sub.sectionId!.isNotEmpty) {
          return sub.sectionId == sec.id;
        }
        final deptMatch =
            sub.departmentId.isEmpty || sub.departmentId == sec.departmentId;
        final semMatch = sub.semester == sec.semester;
        return deptMatch && semMatch;
      }).toList();

      sectionSubjects[sec.id] = secSubjs;

      final secTheorySubjs = secSubjs.where((s) => !s.isLab).toList();
      final secLabSubjs = secSubjs.where((s) => s.isLab).toList();

      // Theory / Regular classes
      for (final subj in secTheorySubjs) {
        final hours = subj.hoursPerWeek;
        for (var h = 0; h < hours; h++) {
          sessionRequests.add(
            _ClassSessionRequest(
              section: sec,
              subject: subj,
              batch: null,
              sessionIndex: h,
              durationPeriods: 1,
            ),
          );
        }
      }

      // Lab classes
      final batches = sec.batches;
      if (secLabSubjs.isNotEmpty) {
        if (batches.isEmpty) {
          // Lab batches not configured: placeholder requests so pre-check flags missingLabBatches
          for (final subj in secLabSubjs) {
            sessionRequests.add(
              _ClassSessionRequest(
                section: sec,
                subject: subj,
                batch: null,
                sessionIndex: 0,
                durationPeriods: subj.consecutivePeriods >= 2 ? subj.consecutivePeriods : 2,
              ),
            );
          }
        } else {
          // Independent batch lab sessions with Cross-Batch Subject Rotation:
          // Treat every section batch as an independent scheduling entity.
          // Each batch receives all required lab sessions independently.
          // Organize requests into rotated rounds across batches:
          // Subjects are partitioned into chunks of at most batches.length.
          // For each chunk:
          //   - If chunk.length == batches.length: full rotation of batches across distinct subjects
          //   - If chunk.length < batches.length: remainder subjects cannot be doubled up across
          //     batches, so at most chunk.length batches run distinct subjects simultaneously,
          //     leaving the other batches FREE during that round.
          final batchNeeds = <String, List<_ClassSessionRequest>>{};
          for (final batch in batches) {
            batchNeeds[batch] = [];
          }

          for (final subj in secLabSubjs) {
            final blockDur =
                subj.consecutivePeriods >= 2 ? subj.consecutivePeriods : 2;

            int sessionsPerBatch;
            if (subj.hoursPerWeek >= blockDur * batches.length) {
              final totalSessions =
                  (subj.hoursPerWeek / blockDur).round().clamp(1, 20);
              sessionsPerBatch =
                  (totalSessions / batches.length).round().clamp(1, 10);
            } else {
              sessionsPerBatch =
                  (subj.hoursPerWeek / blockDur).round().clamp(1, 20);
            }

            for (final batch in batches) {
              for (var s = 0; s < sessionsPerBatch; s++) {
                batchNeeds[batch]!.add(
                  _ClassSessionRequest(
                    section: sec,
                    subject: subj,
                    batch: batch,
                    sessionIndex: s,
                    durationPeriods: blockDur,
                  ),
                );
              }
            }
          }

          var nextLabRoundIndex = 0;
          for (var cStart = 0; cStart < secLabSubjs.length; cStart += batches.length) {
            final cEnd = (cStart + batches.length).clamp(0, secLabSubjs.length);
            final chunk = secLabSubjs.sublist(cStart, cEnd);
            final k = chunk.length;

            while (batches.any((b) => batchNeeds[b]!.any((r) => chunk.any((s) => s.id == r.subject.id)))) {
              if (k == batches.length) {
                // Full group: rotate batches through all subjects in this chunk
                for (var r = 0; r < batches.length; r++) {
                  final currentRound = nextLabRoundIndex++;
                  for (var bIdx = 0; bIdx < batches.length; bIdx++) {
                    final batch = batches[bIdx];
                    final targetSubj = chunk[(bIdx + r) % batches.length];
                    final reqIdx = batchNeeds[batch]!.indexWhere((req) => req.subject.id == targetSubj.id);
                    if (reqIdx >= 0) {
                      final req = batchNeeds[batch]!.removeAt(reqIdx);
                      sessionRequests.add(
                        _ClassSessionRequest(
                          section: req.section,
                          subject: req.subject,
                          batch: req.batch,
                          sessionIndex: req.sessionIndex,
                          durationPeriods: req.durationPeriods,
                          labRoundIndex: currentRound,
                        ),
                      );
                    }
                  }
                }
              } else {
                // Remainder group (k < batches.length):
                // Each round has at most k different subjects; remaining batches are FREE.
                for (var r = 0; r < batches.length; r++) {
                  final currentRound = nextLabRoundIndex++;
                  for (var j = 0; j < k; j++) {
                    final bIdx = (r + j) % batches.length;
                    final batch = batches[bIdx];
                    final targetSubj = chunk[j];
                    final reqIdx = batchNeeds[batch]!.indexWhere((req) => req.subject.id == targetSubj.id);
                    if (reqIdx >= 0) {
                      final req = batchNeeds[batch]!.removeAt(reqIdx);
                      sessionRequests.add(
                        _ClassSessionRequest(
                          section: req.section,
                          subject: req.subject,
                          batch: req.batch,
                          sessionIndex: req.sessionIndex,
                          durationPeriods: req.durationPeriods,
                          labRoundIndex: currentRound,
                        ),
                      );
                    }
                  }
                }
              }
            }
          }

          // Safety drain: process any leftover requests ensuring distinct subjects per round
          while (batchNeeds.values.any((list) => list.isNotEmpty)) {
            final currentRound = nextLabRoundIndex++;
            final usedSubjectsThisRound = <String>{};
            for (final batch in batches) {
              final needs = batchNeeds[batch]!;
              if (needs.isEmpty) continue;
              final idx = needs.indexWhere((r) => !usedSubjectsThisRound.contains(r.subject.id));
              if (idx >= 0) {
                final req = needs.removeAt(idx);
                usedSubjectsThisRound.add(req.subject.id);
                sessionRequests.add(
                  _ClassSessionRequest(
                    section: req.section,
                    subject: req.subject,
                    batch: req.batch,
                    sessionIndex: req.sessionIndex,
                    durationPeriods: req.durationPeriods,
                    labRoundIndex: currentRound,
                  ),
                );
              }
            }
          }
        }
      }
    }

    // Precalculate total required academic periods per section (distinct timetable periods)
    final sectionTotalPeriods = <String, int>{};
    final seenLabRounds = <String>{};
    for (final req in sessionRequests) {
      if (req.isLab && req.batch != null) {
        final roundKey = '${req.section.id}_${req.labRoundIndex}';
        if (seenLabRounds.add(roundKey)) {
          sectionTotalPeriods[req.section.id] =
              (sectionTotalPeriods[req.section.id] ?? 0) + req.durationPeriods;
        }
      } else {
        sectionTotalPeriods[req.section.id] =
            (sectionTotalPeriods[req.section.id] ?? 0) + req.durationPeriods;
      }
    }

    // Precalculate teacher tightness metrics for enhanced MRV
    final teacherTotalHours = <String, int>{};
    for (final sec in targetSections) {
      final secSubjs = sectionSubjects[sec.id] ?? [];
      for (final subj in secSubjs) {
        for (final tid in subj.assignedTeacherIds) {
          teacherTotalHours[tid] =
              (teacherTotalHours[tid] ?? 0) + subj.hoursPerWeek;
        }
      }
    }

    final teacherAvailSlots = <String, int>{};
    for (final staff in staffList) {
      var count = 0;
      for (final day in days) {
        for (final slot in academicSlots) {
          final isUnavail = availabilities.any(
            (a) =>
                a.teacherId == staff.id &&
                a.dayOfWeek == day &&
                a.periodNumber == slot.periodNumber &&
                (!a.isAvailable || a.isLeave),
          );
          if (!isUnavail && !staff.isUnavailableDuring(day: day, slot: slot)) {
            count++;
          }
        }
      }
      teacherAvailSlots[staff.id] = count;
    }

    // 5. Sort requests by MRV (Most Constrained Variable)
    sessionRequests.sort((a, b) {
      // 1. Duration first (multi-period lab blocks harder to fit)
      if (b.durationPeriods != a.durationPeriods) {
        return b.durationPeriods.compareTo(a.durationPeriods);
      }
      // If both are labs of the same section, preserve parallel rotated round grouping
      if (a.isLab && b.isLab && a.section.id == b.section.id) {
        if (a.labRoundIndex != b.labRoundIndex) {
          return a.labRoundIndex.compareTo(b.labRoundIndex);
        }
      }
      // 2. Room restriction (Specialized labs needing 2 rooms harder to fit than Classrooms)
      final aSpecialized = a.subject.isLab
          ? 2
          : (a.subject.requiredRoomType != 'Classroom' ? 1 : 0);
      final bSpecialized = b.subject.isLab
          ? 2
          : (b.subject.requiredRoomType != 'Classroom' ? 1 : 0);
      if (bSpecialized != aSpecialized) {
        return bSpecialized.compareTo(aSpecialized);
      }
      // 3. Teacher scarcity (fewest assigned/authorized teachers)
      final aTeachers = a.subject.assignedTeacherIds.length;
      final bTeachers = b.subject.assignedTeacherIds.length;
      if (aTeachers != bTeachers) {
        return aTeachers.compareTo(bTeachers);
      }
      // 4. Fewest available slots for assigned teacher(s)
      int aMinSlots = 999;
      for (final tid in a.subject.assignedTeacherIds) {
        final cnt = teacherAvailSlots[tid] ?? 25;
        if (cnt < aMinSlots) aMinSlots = cnt;
      }
      int bMinSlots = 999;
      for (final tid in b.subject.assignedTeacherIds) {
        final cnt = teacherAvailSlots[tid] ?? 25;
        if (cnt < bMinSlots) bMinSlots = cnt;
      }
      if (aMinSlots != bMinSlots) {
        return aMinSlots.compareTo(bMinSlots);
      }
      // 5. Highest teacher workload ratio
      int aMaxLoad = 0;
      for (final tid in a.subject.assignedTeacherIds) {
        final ld = teacherTotalHours[tid] ?? 0;
        if (ld > aMaxLoad) aMaxLoad = ld;
      }
      int bMaxLoad = 0;
      for (final tid in b.subject.assignedTeacherIds) {
        final ld = teacherTotalHours[tid] ?? 0;
        if (ld > bMaxLoad) bMaxLoad = ld;
      }
      if (aMaxLoad != bMaxLoad) {
        return bMaxLoad.compareTo(aMaxLoad);
      }
      // 6. Higher weekly hours first
      return b.subject.hoursPerWeek.compareTo(a.subject.hoursPerWeek);
    });

    // 6. Tracking State for Constraint Satisfaction
    // Occupancy sets: "day_period_entityId"
    final teacherOccupancy = <String>{};
    final roomOccupancy = <String>{};
    final sectionOccupancy = <String>{};
    final batchOccupancy = <String>{};
    final sectionMap = {for (final s in sections) s.id: s};

    // Teacher daily count: "day_teacherId" -> count
    final teacherDayCount = <String, int>{};

    // Subject day count: "day_sectionId_subjectId" -> count
    final subjectDayCount = <String, int>{};

    // Section daily academic periods: "day_sectionId" -> count
    final sectionDayPeriods = <String, int>{};

    // Scheduled entries
    final scheduledEntries = <TimetableEntry>[];
    final unresolvableConflicts = <ConflictItem>[];

    // Helper: slot key
    String slotKey(String day, int period, String id) => '${day}_${period}_$id';

    // Fast lookup maps
    final subjectMap = {for (var s in subjects) s.id: s};
    final staffMap = {for (var s in staffList) s.id: s};

    // Pre-populate occupancy from existing entries of OTHER sections (and persistent ACTIVITY entries of target sections)
    final targetSectionIds = targetSections.map((s) => s.id).toSet();
    final otherSectionEntries = <TimetableEntry>[];
    final teacherPeriodsRecorded = <String>{};
    final sectionPeriodsRecorded = <String>{};
    if (existingEntries != null && existingEntries.isNotEmpty) {
      for (final entry in existingEntries) {
        if (entry.status == 'cancelled') continue;
        if (targetSectionIds.contains(entry.sectionId)) {
          if (entry.isActivity) {
            // Activities are persistent manual timetable events and must not be wiped during generation
            scheduledEntries.add(entry);
          } else {
            // Skip target sections' existing class entries so they get fresh placements
            continue;
          }
        } else {
          otherSectionEntries.add(entry);
        }

        if (!entry.isActivity && entry.teacherId.isNotEmpty) {
          teacherOccupancy.add(
            slotKey(entry.dayOfWeek, entry.periodNumber, entry.teacherId),
          );
          final teacherPeriodKey =
              '${entry.dayOfWeek}_${entry.periodNumber}_${entry.teacherId}';
          if (teacherPeriodsRecorded.add(teacherPeriodKey)) {
            teacherDayCount['${entry.dayOfWeek}_${entry.teacherId}'] =
                (teacherDayCount['${entry.dayOfWeek}_${entry.teacherId}'] ?? 0) +
                1;
          }
        }
        if (entry.roomId.isNotEmpty) {
          roomOccupancy.add(
            slotKey(entry.dayOfWeek, entry.periodNumber, entry.roomId),
          );
        }
        if (entry.batch != null) {
          batchOccupancy.add(
            slotKey(entry.dayOfWeek, entry.periodNumber, '${entry.sectionId}_${entry.batch}'),
          );
        } else {
          sectionOccupancy.add(
            slotKey(entry.dayOfWeek, entry.periodNumber, entry.sectionId),
          );
          final sec = sectionMap[entry.sectionId];
          if (sec != null) {
            for (final b in sec.batches) {
              batchOccupancy.add(
                slotKey(entry.dayOfWeek, entry.periodNumber, '${entry.sectionId}_$b'),
              );
            }
          }
        }

        if (!entry.isActivity && entry.subjectId.isNotEmpty) {
          final sKey = resolveSubjectKey(
            subjectId: entry.subjectId,
            subjectMap: subjectMap,
            subjects: subjects,
          );
          final isLabSub = isLabEntry(
            entry: entry,
            subjectMap: subjectMap,
            subjects: subjects,
          );
          if (!isLabSub) {
            subjectDayCount['${entry.dayOfWeek}_${entry.sectionId}_$sKey'] =
                (subjectDayCount['${entry.dayOfWeek}_${entry.sectionId}_$sKey'] ?? 0) + 1;
          } else if (entry.batch != null) {
            subjectDayCount['${entry.dayOfWeek}_${entry.sectionId}_${sKey}_${entry.batch}'] =
                (subjectDayCount['${entry.dayOfWeek}_${entry.sectionId}_${sKey}_${entry.batch}'] ?? 0) + 1;
          }
        }
        final sectionPeriodKey =
            '${entry.dayOfWeek}_${entry.periodNumber}_${entry.sectionId}';
        if (sectionPeriodsRecorded.add(sectionPeriodKey)) {
          sectionDayPeriods['${entry.dayOfWeek}_${entry.sectionId}'] =
              (sectionDayPeriods['${entry.dayOfWeek}_${entry.sectionId}'] ?? 0) +
              1;
        }
      }
    }


    // 7. Helper: Find candidate placements for a session request
    List<_CandidatePlacement> getCandidatePlacements(_ClassSessionRequest req) {
      final sec = req.section;
      final subj = req.subject;
      final duration = req.durationPeriods;

      final authorizedTeachers = staffList.where((staff) {
        if (!staff.active || staff.status == 'inactive') return false;
        final isAssigned =
            subj.assignedTeacherIds.isEmpty ||
            subj.assignedTeacherIds.contains(staff.id);
        if (!isAssigned) return false;
        return staff.isEligibleForSubject(
          subjectName: subj.subjectName,
          subjectCode: subj.subjectCode,
          courseShortName: subj.courseShortName,
          subjectId: subj.id,
        );
      }).toList();

      final eligibleRooms = activeRooms.where((room) {
        if (!isRoomEligibleForSubject(room: room, subject: subj, section: sec)) {
          return false;
        }
        if (subj.isLab) {
          final batchDivisor = sec.batches.isNotEmpty
              ? sec.batches.length
              : (req.batchNames.isNotEmpty ? req.batchNames.length : 1);
          if (room.capacity < (sec.studentCount / batchDivisor).ceil()) {
            return false;
          }
          return true;
        } else {
          if (room.capacity < sec.studentCount) return false;
          return true;
        }
      }).toList();

      final subKey = resolveSubjectKey(
        subjectId: subj.id,
        subjectMap: subjectMap,
        subjects: subjects,
      );

      final candidates = <_CandidatePlacement>[];

      int computeCandidateScore({
        required String day,
        required List<int> periodSequence,
        required Staff teacher,
      }) {
        final pStart = periodSequence.first;
        var score = 100;

        // Find existing scheduled entries for other batches of this section in this slot
        final parallelLabEntries = (req.isLab && req.batch != null)
            ? scheduledEntries
                .where(
                  (e) =>
                      e.sectionId == sec.id &&
                      e.dayOfWeek == day &&
                      periodSequence.contains(e.periodNumber) &&
                      e.batch != null &&
                      e.batch != req.batch,
                )
                .toList()
            : const <TimetableEntry>[];

        final hasSameSubject = parallelLabEntries.any(
          (e) => e.subjectId == subj.id,
        );
        final isParallelDifferentLab =
            parallelLabEntries.isNotEmpty && !hasSameSubject;

        // Distinct periods occupied by this section on this day
        final secOccupiedPeriodsOnDay = <int>{};
        for (final p in validPeriodNumbers) {
          if (sectionOccupancy.contains(slotKey(day, p, sec.id))) {
            secOccupiedPeriodsOnDay.add(p);
          }
        }
        for (final e in scheduledEntries) {
          if (e.sectionId == sec.id && e.dayOfWeek == day) {
            secOccupiedPeriodsOnDay.add(e.periodNumber);
          }
        }

        final newPeriodsForSection = periodSequence
            .where((p) => !secOccupiedPeriodsOnDay.contains(p))
            .length;
        final effectiveSectionDayPeriods =
            secOccupiedPeriodsOnDay.length + newPeriodsForSection;

        // 1. Weekly distribution & empty working days soft objective
        final totalNeeded = sectionTotalPeriods[sec.id] ?? 0;
        final emptyDaysCount = days.where(
          (d) => (sectionDayPeriods['${d}_${sec.id}'] ?? 0) == 0,
        ).length;
        final usedDaysCount = days.length - emptyDaysCount;
        final hasEnoughClassesForEveryDay = totalNeeded >= days.length;
        final maxTargetPerDay = days.isNotEmpty
            ? (totalNeeded / days.length).ceil()
            : 0;

        // When a batch is joining a parallel lab block of a different subject,
        // it shouldn't be penalized for not choosing an empty day.
        if (hasEnoughClassesForEveryDay) {
          if (secOccupiedPeriodsOnDay.isEmpty) {
            score += 80;
          } else if (emptyDaysCount > 0 && !isParallelDifferentLab) {
            score -= 60;
          }
        } else {
          if (secOccupiedPeriodsOnDay.isEmpty && usedDaysCount < totalNeeded) {
            score += 80;
          } else if (secOccupiedPeriodsOnDay.isNotEmpty &&
              usedDaysCount < totalNeeded &&
              !isParallelDifferentLab) {
            score -= 60;
          }
        }

        // 2. Balance classes across working days
        score -= effectiveSectionDayPeriods * 15;

        // Penalize exceeding the fair-share target daily limit
        if (maxTargetPerDay > 0 && effectiveSectionDayPeriods > maxTargetPerDay) {
          score -= 80 * (effectiveSectionDayPeriods - maxTargetPerDay);
        }

        // 3. Spread the same subject across different days
        final timesScheduledOnDay =
            subjectDayCount['${day}_${sec.id}_$subKey'] ?? 0;
        if (timesScheduledOnDay > 0) {
          score -= 50 * timesScheduledOnDay;
        }
        if (subj.isLab && timesScheduledOnDay > 0) {
          score -= 100 * timesScheduledOnDay; // Strong preference for different days for batch labs
        }

        // 3b. Cross-Batch Parallel Lab Scheduling Preference
        if (req.isLab && req.batch != null && parallelLabEntries.isNotEmpty) {
          if (hasSameSubject) {
            // Heavily disfavor scheduling identical lab subjects across batches simultaneously
            score -= 600;
          } else {
            // Strongly reward scheduling DIFFERENT lab subjects across batches in parallel!
            score += 450;

            // Alignment bonus: both batches start and end at the exact same periods
            final otherPeriods =
                parallelLabEntries.map((e) => e.periodNumber).toSet();
            if (periodSequence.every((p) => otherPeriods.contains(p))) {
              score += 150;
            }
          }
        }

        // 4. Compactness & Gap-Avoidance: Make timetable as continuous as possible (Scheduling Rule)
        final pStartIdx = validPeriodNumbers.indexOf(pStart);
        final pEnd = periodSequence.last;
        final pEndIdx = validPeriodNumbers.indexOf(pEnd);

        // Find existing scheduled periods for this section on this day
        final existingSecPeriods = <int>[];
        for (final p in validPeriodNumbers) {
          if (sectionOccupancy.contains(slotKey(day, p, sec.id))) {
            existingSecPeriods.add(p);
          }
        }

        final combinedPeriods = {...existingSecPeriods, ...periodSequence}.toList()..sort();
        final minPeriod = combinedPeriods.first;
        final maxPeriod = combinedPeriods.last;
        final internalGaps = (maxPeriod - minPeriod + 1) - combinedPeriods.length;

        // A. Heavily penalize any avoidable internal gaps between classes on the same day
        if (internalGaps > 0) {
          score -= internalGaps * 150;
        } else if (existingSecPeriods.isNotEmpty) {
          // Contiguous schedule bonus: perfectly attaches to existing classes with zero internal gaps!
          score += 80;
        }

        // B. Reward direct adjacency to already-scheduled classes on this day
        final touchesBefore = pStartIdx > 0 &&
            sectionOccupancy.contains(slotKey(day, validPeriodNumbers[pStartIdx - 1], sec.id));
        final touchesAfter = pEndIdx < validPeriodNumbers.length - 1 &&
            sectionOccupancy.contains(slotKey(day, validPeriodNumbers[pEndIdx + 1], sec.id));

        if (touchesBefore && touchesAfter) {
          score += 60; // Perfectly fills a gap between two scheduled classes!
        } else if (touchesBefore || touchesAfter) {
          score += 40; // Contiguously extends an existing cluster of classes!
        }

        // C. Prefer earlier available periods when possible (Scheduling Rule 2)
        score -= pStartIdx * 15;

        // 5. Teacher preference
        for (final p in periodSequence) {
          if (teacher.preferredPeriodNumbers.contains(p)) {
            score += 10;
          }
        }

        // 6. Teacher consecutive classes fatigue check
        if (pStartIdx > 0) {
          final prevPeriod = validPeriodNumbers[pStartIdx - 1];
          if (teacherOccupancy.contains(slotKey(day, prevPeriod, teacher.id))) {
            score -= 10;
          }
        }

        return score;
      }

      for (final day in days) {
        // Enforce hard constraint: A theory/regular subject may have at most ONE scheduled session per day for this section.
        if (!subj.isLab) {
          final alreadyScheduledOnDay =
              (subjectDayCount['${day}_${sec.id}_$subKey'] ?? 0) > 0;
          if (alreadyScheduledOnDay) {
            continue;
          }
        } else if (req.batch != null) {
          // A batch cannot take the same lab twice on the same day
          final alreadyScheduledOnDay =
              (subjectDayCount['${day}_${sec.id}_${subKey}_${req.batch}'] ?? 0) > 0;
          if (alreadyScheduledOnDay) {
            continue;
          }
        }
        for (
          var pIdx = 0;
          pIdx <= validPeriodNumbers.length - duration;
          pIdx++
        ) {
          bool consecutiveValid = true;
          final periodSequence = <int>[];
          for (var d = 0; d < duration; d++) {
            final period = validPeriodNumbers[pIdx + d];
            if (d > 0 && period != validPeriodNumbers[pIdx + d - 1] + 1) {
              consecutiveValid = false;
              break;
            }
            if (d > 0) {
              final previousSlotIndex = orderedAllSlots.indexWhere(
                (s) =>
                    !s.isBreak &&
                    s.periodNumber == validPeriodNumbers[pIdx + d - 1],
              );
              final currentSlotIndex = orderedAllSlots.indexWhere(
                (s) => !s.isBreak && s.periodNumber == period,
              );
              if (previousSlotIndex < 0 ||
                  currentSlotIndex != previousSlotIndex + 1) {
                consecutiveValid = false;
                break;
              }
            }
            periodSequence.add(period);
          }
          if (!consecutiveValid) continue;

          // Section / batch occupancy check
          if (periodSequence.any(
            (p) => sectionOccupancy.contains(slotKey(day, p, sec.id)),
          )) {
            continue;
          }
          if (req.batch != null) {
            // A batch cannot be scheduled if that specific batch is already occupied at this time
            if (periodSequence.any(
              (p) => batchOccupancy.contains(slotKey(day, p, '${sec.id}_${req.batch}')),
            )) {
              continue;
            }
          } else {
            // Whole-section class: cannot overlap with ANY batch of sec that is in a lab
            if (periodSequence.any(
              (p) => sec.batches.any(
                (b) => batchOccupancy.contains(slotKey(day, p, '${sec.id}_$b')),
              ),
            )) {
              continue;
            }
          }

          for (final teacher in authorizedTeachers) {
            final curDayCount = teacherDayCount['${day}_${teacher.id}'] ?? 0;
            if (curDayCount + duration > teacher.maxClassesPerDay) continue;

            bool teacherAvailable = true;
            for (final p in periodSequence) {
              if (teacherOccupancy.contains(slotKey(day, p, teacher.id))) {
                teacherAvailable = false;
                break;
              }
              final isUnavail = availabilities.any(
                (a) =>
                    a.teacherId == teacher.id &&
                    a.dayOfWeek == day &&
                    a.periodNumber == p &&
                    (!a.isAvailable || a.isLeave),
              );
              if (isUnavail) {
                teacherAvailable = false;
                break;
              }

              final matchingSlot = academicSlots.firstWhere(
                (s) => s.periodNumber == p,
                orElse: () => academicSlots.first,
              );
              if (teacher.isUnavailableDuring(day: day, slot: matchingSlot)) {
                teacherAvailable = false;
                break;
              }
            }
            if (!teacherAvailable) continue;

            final score = computeCandidateScore(
              day: day,
              periodSequence: periodSequence,
              teacher: teacher,
            );
            for (final room in eligibleRooms) {
              if (periodSequence.any(
                (p) => roomOccupancy.contains(slotKey(day, p, room.id)),
              )) {
                continue;
              }

              candidates.add(
                _CandidatePlacement(
                  day: day,
                  periodSequence: periodSequence,
                  teacher: teacher,
                  room: room,
                  score: score,
                ),
              );
            }
          }
        }
      }

      candidates.sort((a, b) {
        final scoreCmp = b.score.compareTo(a.score);
        if (scoreCmp != 0) return scoreCmp;
        if (!subj.isLab) {
          return a.periodSequence.first.compareTo(b.periodSequence.first);
        } else {
          return b.periodSequence.first.compareTo(a.periodSequence.first);
        }
      });
      return candidates;
    }

    // Pre-check for impossible sessions: missing authorized teachers or missing compatible rooms
    final unresolvableRequests = <_ClassSessionRequest>{};
    for (final req in sessionRequests) {
      final sec = req.section;
      final subj = req.subject;

      final authorizedTeachers = staffList.where((staff) {
        if (!staff.active || staff.status == 'inactive') return false;
        final isAssigned =
            subj.assignedTeacherIds.isEmpty ||
            subj.assignedTeacherIds.contains(staff.id);
        if (!isAssigned) return false;
        return staff.isEligibleForSubject(
          subjectName: subj.subjectName,
          subjectCode: subj.subjectCode,
          courseShortName: subj.courseShortName,
          subjectId: subj.id,
        );
      }).toList();

      if (authorizedTeachers.isEmpty) {
        unresolvableRequests.add(req);
        unresolvableConflicts.add(
          ConflictItem(
            id: 'unauth_${sec.id}_${subj.id}',
            collegeId: collegeId,
            type: 'unauthorizedTeacher',
            title: 'No Eligible Teacher Available',
            description:
                'No active, eligible teacher is assigned to teach ${subj.subjectName} (${subj.subjectCode}) for ${sec.displayName}.',
            subjectId: subj.id,
            sectionId: sec.id,
            suggestion: 'Assign an eligible teacher to ${subj.subjectName}.',
          ),
        );
        continue;
      }

      if (subj.isLab) {
        final requiredBatches = sec.batches;
        if (requiredBatches.isEmpty) {
          unresolvableRequests.add(req);
          unresolvableConflicts.add(
            ConflictItem(
              id: 'batches_needed_${sec.id}_${subj.id}',
              collegeId: collegeId,
              type: 'missingLabBatches',
              severity: 'hard',
              title: 'Lab Batches Not Configured',
              description:
                  'Section "${sec.displayName}" has no lab batches configured for ${subj.subjectName}.',
              subjectId: subj.id,
              sectionId: sec.id,
              suggestion:
                  'Edit the section and enter its batch names before generating labs.',
            ),
          );
          continue;
        }

        final eligibleLabs = activeRooms.where((room) {
          if (!isRoomEligibleForSubject(room: room, subject: subj, section: sec)) {
            return false;
          }
          if (room.capacity <
              (sec.studentCount / requiredBatches.length).ceil()) {
            return false;
          }
          return true;
        }).toList();

        if (eligibleLabs.isEmpty) {
          unresolvableRequests.add(req);
          unresolvableConflicts.add(
            ConflictItem(
              id: 'rooms_needed_${sec.id}_${subj.id}',
              collegeId: collegeId,
              type: 'roomTypeMismatch',
              severity: 'hard',
              title: subj.allowsClassroom
                  ? 'Suitable Classroom or Lab Required'
                  : 'Suitable Lab Room Required',
              description: subj.allowsClassroom
                  ? 'Lab subject "${subj.subjectName}" (${subj.subjectCode}) for section "${sec.displayName}" requires a suitable classroom or lab with capacity >= ${(sec.studentCount / requiredBatches.length).ceil()} for its configured batches, but no matching rooms were found.'
                  : 'Lab subject "${subj.subjectName}" (${subj.subjectCode}) for section "${sec.displayName}" requires a suitable lab of type "${subj.requiredRoomType}" with capacity >= ${(sec.studentCount / requiredBatches.length).ceil()} for its configured batches, but no matching rooms were found.',
              subjectId: subj.id,
              sectionId: sec.id,
              suggestion: subj.allowsClassroom
                  ? 'Add at least 1 classroom or lab with capacity >= ${(sec.studentCount / requiredBatches.length).ceil()} in Rooms & Labs.'
                  : 'Add at least 1 lab of type "${subj.requiredRoomType}" with capacity >= ${(sec.studentCount / requiredBatches.length).ceil()} in Rooms & Labs.',
            ),
          );
        }
      } else {
        final eligibleRooms = activeRooms.where((room) {
          if (!isRoomEligibleForSubject(room: room, subject: subj, section: sec)) {
            return false;
          }
          if (room.capacity < sec.studentCount) return false;
          return true;
        }).toList();

        if (eligibleRooms.isEmpty) {
          unresolvableRequests.add(req);
          unresolvableConflicts.add(
            ConflictItem(
              id: 'no_classroom_${sec.id}_${subj.id}',
              collegeId: collegeId,
              type: 'capacityConflict',
              severity: 'hard',
              title: 'No Compatible Classroom Available',
              description:
                  'No classroom found with capacity >= ${sec.studentCount} for ${sec.displayName} - ${subj.subjectName}.',
              subjectId: subj.id,
              sectionId: sec.id,
              suggestion:
                  'Add or adjust capacity for a Classroom with capacity at least ${sec.studentCount}.',
            ),
          );
        }
      }
    }

    if (unresolvableConflicts.isNotEmpty) {
      final hasInsufficientLabs = unresolvableConflicts.any(
        (c) =>
            c.title.contains('Suitable Lab') ||
            c.title.contains('Suitable Classroom or Lab') ||
            c.type == 'insufficientLabs' ||
            c.description.contains('requires two suitable labs'),
      );
      final hasMissingBatches = unresolvableConflicts.any(
        (c) => c.type == 'missingLabBatches',
      );
      return GenerationResult(
        isSuccess: false,
        versionId: versionId,
        entries: existingEntries ?? [],
        totalClassesScheduled: 0,
        teachersUsed: 0,
        roomsUsed: 0,
        sectionsScheduled: 0,
        generationTimeMs: stopwatch.elapsedMilliseconds,
        conflicts: unresolvableConflicts,
        summaryMessage: hasMissingBatches
            ? 'Timetable could not be generated because lab batches are not configured for one or more sections.'
            : hasInsufficientLabs
            ? 'Timetable could not be generated because enough suitable lab rooms are not available.'
            : 'Timetable cannot be generated with the current constraints: ${unresolvableConflicts.length} issue(s) detected.',
        targetSectionId: targetSectionId,
      );
    }

    final schedulableRequests = sessionRequests
        .where((r) => !unresolvableRequests.contains(r))
        .toList();

    // 8. Backtracking Constraint Satisfaction Search
    var backtrackSteps = 0;
    const maxBacktrackSteps = 50000;

    List<TimetableEntry> bestScheduledEntries = [];
    int maxScheduledCount = 0;

    bool backtrackSearch(int reqIdx) {
      backtrackSteps++;
      if (backtrackSteps > maxBacktrackSteps) {
        return false;
      }

      if (scheduledEntries.length > maxScheduledCount) {
        maxScheduledCount = scheduledEntries.length;
        bestScheduledEntries = List.from(scheduledEntries);
      }

      if (reqIdx == schedulableRequests.length) {
        return true;
      }

      final req = schedulableRequests[reqIdx];
      final candidates = getCandidatePlacements(req);

      for (final cand in candidates) {
        final sec = req.section;
        final subj = req.subject;
        final duration = req.durationPeriods;
        final entriesAdded = <TimetableEntry>[];

        for (final p in cand.periodSequence) {
          final matchingSlot = academicSlots.firstWhere(
            (s) => s.periodNumber == p,
            orElse: () => academicSlots.first,
          );

          final entry = TimetableEntry(
            id: _uuid.v4(),
            collegeId: collegeId,
            versionId: versionId,
            dayOfWeek: cand.day,
            periodNumber: p,
            timeSlotId: matchingSlot.id,
            sectionId: sec.id,
            subjectId: subj.id,
            teacherId: cand.teacher.id,
            roomId: cand.room.id,
            batch: req.batch,
            status: 'draft',
          );
          entriesAdded.add(entry);
          scheduledEntries.add(entry);

          teacherOccupancy.add(slotKey(cand.day, p, cand.teacher.id));
          roomOccupancy.add(slotKey(cand.day, p, cand.room.id));

          if (req.batch != null) {
            batchOccupancy.add(slotKey(cand.day, p, '${sec.id}_${req.batch}'));
          } else {
            sectionOccupancy.add(slotKey(cand.day, p, sec.id));
            for (final b in sec.batches) {
              batchOccupancy.add(slotKey(cand.day, p, '${sec.id}_$b'));
            }
          }
        }

        final secDayKey = '${cand.day}_${sec.id}';
        var newlyOccupiedPeriodsCount = 0;
        for (final p in cand.periodSequence) {
          final alreadyOccupied = scheduledEntries
              .take(scheduledEntries.length - entriesAdded.length)
              .any(
                (e) =>
                    e.sectionId == sec.id &&
                    e.dayOfWeek == cand.day &&
                    e.periodNumber == p,
              );
          if (!alreadyOccupied) {
            newlyOccupiedPeriodsCount++;
          }
        }

        teacherDayCount['${cand.day}_${cand.teacher.id}'] =
            (teacherDayCount['${cand.day}_${cand.teacher.id}'] ?? 0) + duration;
        final candSubKey = resolveSubjectKey(
          subjectId: subj.id,
          subjectMap: subjectMap,
          subjects: subjects,
        );
        if (!subj.isLab) {
          subjectDayCount['${cand.day}_${sec.id}_$candSubKey'] =
              (subjectDayCount['${cand.day}_${sec.id}_$candSubKey'] ?? 0) + 1;
        } else if (req.batch != null) {
          subjectDayCount['${cand.day}_${sec.id}_${candSubKey}_${req.batch}'] =
              (subjectDayCount['${cand.day}_${sec.id}_${candSubKey}_${req.batch}'] ?? 0) + 1;
        }
        sectionDayPeriods[secDayKey] =
            (sectionDayPeriods[secDayKey] ?? 0) + newlyOccupiedPeriodsCount;

        if (backtrackSearch(reqIdx + 1)) {
          return true;
        }

        // Backtrack: Undo placement
        for (final entry in entriesAdded) {
          scheduledEntries.removeLast();
          teacherOccupancy.remove(
            slotKey(cand.day, entry.periodNumber, entry.teacherId),
          );
          roomOccupancy.remove(
            slotKey(cand.day, entry.periodNumber, entry.roomId),
          );
          if (entry.batch != null) {
            batchOccupancy.remove(
              slotKey(cand.day, entry.periodNumber, '${sec.id}_${entry.batch}'),
            );
          } else {
            sectionOccupancy.remove(
              slotKey(cand.day, entry.periodNumber, sec.id),
            );
            for (final b in sec.batches) {
              batchOccupancy.remove(
                slotKey(cand.day, entry.periodNumber, '${sec.id}_$b'),
              );
            }
          }
        }
        teacherDayCount['${cand.day}_${cand.teacher.id}'] =
            (teacherDayCount['${cand.day}_${cand.teacher.id}'] ?? 0) - duration;
        if (!subj.isLab) {
          subjectDayCount['${cand.day}_${sec.id}_$candSubKey'] =
              (subjectDayCount['${cand.day}_${sec.id}_$candSubKey'] ?? 0) - 1;
        } else if (req.batch != null) {
          subjectDayCount['${cand.day}_${sec.id}_${candSubKey}_${req.batch}'] =
              (subjectDayCount['${cand.day}_${sec.id}_${candSubKey}_${req.batch}'] ?? 0) - 1;
        }
        sectionDayPeriods[secDayKey] =
            (sectionDayPeriods[secDayKey] ?? 0) - newlyOccupiedPeriodsCount;
      }

      return false;
    }

    final searchSuccess = backtrackSearch(0);

    if (!searchSuccess) {
      // Restore best partial schedule found
      scheduledEntries
        ..clear()
        ..addAll(bestScheduledEntries);

      // Rebuild occupancy sets and counts for the best partial schedule
      teacherOccupancy.clear();
      roomOccupancy.clear();
      sectionOccupancy.clear();
      batchOccupancy.clear();
      teacherDayCount.clear();
      subjectDayCount.clear();
      sectionDayPeriods.clear();

      teacherPeriodsRecorded.clear();
      sectionPeriodsRecorded.clear();

      for (final entry in otherSectionEntries) {
        if (!entry.isActivity && entry.teacherId.isNotEmpty) {
          teacherOccupancy.add(
            slotKey(entry.dayOfWeek, entry.periodNumber, entry.teacherId),
          );
        }
        if (entry.roomId.isNotEmpty) {
          roomOccupancy.add(
            slotKey(entry.dayOfWeek, entry.periodNumber, entry.roomId),
          );
        }
        if (entry.batch != null) {
          batchOccupancy.add(
            slotKey(entry.dayOfWeek, entry.periodNumber, '${entry.sectionId}_${entry.batch}'),
          );
        } else {
          sectionOccupancy.add(
            slotKey(entry.dayOfWeek, entry.periodNumber, entry.sectionId),
          );
          final sec = sectionMap[entry.sectionId];
          if (sec != null) {
            for (final b in sec.batches) {
              batchOccupancy.add(
                slotKey(entry.dayOfWeek, entry.periodNumber, '${entry.sectionId}_$b'),
              );
            }
          }
        }
        if (!entry.isActivity && entry.teacherId.isNotEmpty) {
          final teacherPeriodKey =
              '${entry.dayOfWeek}_${entry.periodNumber}_${entry.teacherId}';
          if (teacherPeriodsRecorded.add(teacherPeriodKey)) {
            teacherDayCount['${entry.dayOfWeek}_${entry.teacherId}'] =
                (teacherDayCount['${entry.dayOfWeek}_${entry.teacherId}'] ?? 0) +
                1;
          }
        }
        if (!entry.isActivity && entry.subjectId.isNotEmpty) {
          final sKey = resolveSubjectKey(
            subjectId: entry.subjectId,
            subjectMap: subjectMap,
            subjects: subjects,
          );
          final isLabSub = isLabEntry(
            entry: entry,
            subjectMap: subjectMap,
            subjects: subjects,
          );
          if (!isLabSub) {
            subjectDayCount['${entry.dayOfWeek}_${entry.sectionId}_$sKey'] =
                (subjectDayCount['${entry.dayOfWeek}_${entry.sectionId}_$sKey'] ?? 0) + 1;
          } else if (entry.batch != null) {
            subjectDayCount['${entry.dayOfWeek}_${entry.sectionId}_${sKey}_${entry.batch}'] =
                (subjectDayCount['${entry.dayOfWeek}_${entry.sectionId}_${sKey}_${entry.batch}'] ?? 0) + 1;
          }
        }
        final sectionPeriodKey =
            '${entry.dayOfWeek}_${entry.periodNumber}_${entry.sectionId}';
        if (sectionPeriodsRecorded.add(sectionPeriodKey)) {
          sectionDayPeriods['${entry.dayOfWeek}_${entry.sectionId}'] =
              (sectionDayPeriods['${entry.dayOfWeek}_${entry.sectionId}'] ?? 0) +
              1;
        }
      }
      for (final entry in scheduledEntries) {
        if (!entry.isActivity && entry.teacherId.isNotEmpty) {
          teacherOccupancy.add(
            slotKey(entry.dayOfWeek, entry.periodNumber, entry.teacherId),
          );
        }
        if (entry.roomId.isNotEmpty) {
          roomOccupancy.add(
            slotKey(entry.dayOfWeek, entry.periodNumber, entry.roomId),
          );
        }
        if (entry.batch != null) {
          batchOccupancy.add(
            slotKey(entry.dayOfWeek, entry.periodNumber, '${entry.sectionId}_${entry.batch}'),
          );
        } else {
          sectionOccupancy.add(
            slotKey(entry.dayOfWeek, entry.periodNumber, entry.sectionId),
          );
          final sec = sectionMap[entry.sectionId];
          if (sec != null) {
            for (final b in sec.batches) {
              batchOccupancy.add(
                slotKey(entry.dayOfWeek, entry.periodNumber, '${entry.sectionId}_$b'),
              );
            }
          }
        }
        if (!entry.isActivity && entry.teacherId.isNotEmpty) {
          final teacherPeriodKey =
              '${entry.dayOfWeek}_${entry.periodNumber}_${entry.teacherId}';
          if (teacherPeriodsRecorded.add(teacherPeriodKey)) {
            teacherDayCount['${entry.dayOfWeek}_${entry.teacherId}'] =
                (teacherDayCount['${entry.dayOfWeek}_${entry.teacherId}'] ?? 0) +
                1;
          }
        }
        if (!entry.isActivity && entry.subjectId.isNotEmpty) {
          final sKey = resolveSubjectKey(
            subjectId: entry.subjectId,
            subjectMap: subjectMap,
            subjects: subjects,
          );
          final isLabSub = isLabEntry(
            entry: entry,
            subjectMap: subjectMap,
            subjects: subjects,
          );
          if (!isLabSub) {
            subjectDayCount['${entry.dayOfWeek}_${entry.sectionId}_$sKey'] =
                (subjectDayCount['${entry.dayOfWeek}_${entry.sectionId}_$sKey'] ?? 0) + 1;
          } else if (entry.batch != null) {
            subjectDayCount['${entry.dayOfWeek}_${entry.sectionId}_${sKey}_${entry.batch}'] =
                (subjectDayCount['${entry.dayOfWeek}_${entry.sectionId}_${sKey}_${entry.batch}'] ?? 0) + 1;
          }
        }
        final sectionPeriodKey =
            '${entry.dayOfWeek}_${entry.periodNumber}_${entry.sectionId}';
        if (sectionPeriodsRecorded.add(sectionPeriodKey)) {
          sectionDayPeriods['${entry.dayOfWeek}_${entry.sectionId}'] =
              (sectionDayPeriods['${entry.dayOfWeek}_${entry.sectionId}'] ?? 0) +
              1;
        }
      }

      // Identify which requests could not be scheduled
      final scheduledCounts = <String, int>{};
      for (final entry in scheduledEntries) {
        final key = '${entry.sectionId}_${entry.subjectId}_${entry.batch ?? ''}';
        scheduledCounts[key] = (scheduledCounts[key] ?? 0) + 1;
      }

      final placedPerSubject = <String, int>{};
      final unscheduledRequests = <_ClassSessionRequest>[];
      for (final req in schedulableRequests) {
        final key = '${req.section.id}_${req.subject.id}_${req.batch ?? ''}';
        final needed = (placedPerSubject[key] ?? 0) + req.durationPeriods;
        final placed = scheduledCounts[key] ?? 0;
        if (needed > placed) {
          unscheduledRequests.add(req);
        } else {
          placedPerSubject[key] = needed;
        }
      }

      // Generate structured diagnostic conflicts for unscheduled requests (Task 6)
      for (final req in unscheduledRequests) {
        final authorizedTeachers = staffList.where((staff) {
          if (!staff.active || staff.status == 'inactive') return false;
          final isAssigned =
              req.subject.assignedTeacherIds.isEmpty ||
              req.subject.assignedTeacherIds.contains(staff.id);
          if (!isAssigned) return false;
          return staff.isEligibleForSubject(
            subjectName: req.subject.subjectName,
            subjectCode: req.subject.subjectCode,
            courseShortName: req.subject.courseShortName,
            subjectId: req.subject.id,
          );
        }).toList();

        final eligibleRooms = activeRooms.where((room) {
          if (!isRoomEligibleForSubject(room: room, subject: req.subject, section: req.section)) {
            return false;
          }
          if (req.subject.isLab) {
            final batchDivisor = req.section.batches.isNotEmpty
                ? req.section.batches.length
                : (req.batchNames.isNotEmpty ? req.batchNames.length : 1);
            if (room.capacity <
                (req.section.studentCount / batchDivisor).ceil()) {
              return false;
            }
            return true;
          } else {
            if (room.capacity < req.section.studentCount) return false;
            return true;
          }
        }).toList();

        final conflict = _buildDiagnosticConflict(
          collegeId: collegeId,
          req: req,
          days: days,
          validPeriodNumbers: validPeriodNumbers,
          academicSlots: academicSlots,
          authorizedTeachers: authorizedTeachers,
          eligibleRooms: eligibleRooms,
          sectionOccupancy: sectionOccupancy,
          teacherOccupancy: teacherOccupancy,
          roomOccupancy: roomOccupancy,
          teacherDayCount: teacherDayCount,
          availabilities: availabilities,
          slotKey: slotKey,
          scheduledEntries: scheduledEntries,
          subjectMap: subjectMap,
          staffMap: staffMap,
        );
        unresolvableConflicts.add(conflict);
      }
    }

    // 8a. Conflict-Safe Compaction & Gap-Minimization Pass:
    // Optimizes the timetable to minimize avoidable empty periods and make the schedule compact.
    // Never creates internal gaps; strictly preserves professor, room, section, break, and lab constraints.
    final preCompactionSnapshot = List<TimetableEntry>.from(scheduledEntries);
    final preTeacherOccSnapshot = Set<String>.from(teacherOccupancy);
    final preRoomOccSnapshot = Set<String>.from(roomOccupancy);
    final preSectionOccSnapshot = Set<String>.from(sectionOccupancy);

    try {
      for (final sec in targetSections) {
        for (final day in days) {
          for (var tIdx = 0; tIdx < validPeriodNumbers.length; tIdx++) {
            final targetPeriod = validPeriodNumbers[tIdx];
            if (sectionOccupancy.contains(slotKey(day, targetPeriod, sec.id))) {
              continue;
            }

            for (var sIdx = tIdx + 1; sIdx < validPeriodNumbers.length; sIdx++) {
              final sourcePeriod = validPeriodNumbers[sIdx];
              if (!sectionOccupancy.contains(slotKey(day, sourcePeriod, sec.id))) {
                continue;
              }

              final matchingEntries = scheduledEntries
                  .where(
                    (e) =>
                        e.sectionId == sec.id &&
                        e.dayOfWeek == day &&
                        e.periodNumber == sourcePeriod,
                  )
                  .toList();
              if (matchingEntries.length != 1) continue;

              final entry = matchingEntries.first;
              if (entry.batch != null) continue; // Skip lab batch sessions

              final subj = subjectMap[entry.subjectId];
              if (subj == null || subj.isLab) continue;

              final teacher = staffMap[entry.teacherId];
              if (teacher == null) continue;

              // Check if shifting to targetPeriod would create or increase internal gaps
              final dayPeriods = scheduledEntries
                  .where((e) => e.sectionId == sec.id && e.dayOfWeek == day)
                  .map((e) => e.periodNumber)
                  .toSet()
                  .toList()
                ..sort();
              if (dayPeriods.isEmpty) continue;
              final currentGaps =
                  (dayPeriods.last - dayPeriods.first + 1) - dayPeriods.length;
              final potPeriods = dayPeriods.where((p) => p != sourcePeriod).toSet()
                ..add(targetPeriod);
              final potSorted = potPeriods.toList()..sort();
              final newGaps =
                  (potSorted.last - potSorted.first + 1) - potSorted.length;

              // Do NOT shift if it creates or increases internal gaps!
              if (newGaps > currentGaps) continue;
              if (currentGaps > 0 && newGaps >= currentGaps) continue;

              // Check if teacher is free at targetPeriod
              if (teacherOccupancy.contains(slotKey(day, targetPeriod, teacher.id))) {
                continue;
              }

              // Check teacher availability & leave at targetPeriod
              final isTeacherUnavail = availabilities.any(
                (a) =>
                    a.teacherId == teacher.id &&
                    a.dayOfWeek == day &&
                    a.periodNumber == targetPeriod &&
                    (!a.isAvailable || a.isLeave),
              );
              if (isTeacherUnavail) continue;

              final targetSlot = academicSlots.firstWhere(
                (s) => s.periodNumber == targetPeriod,
                orElse: () => academicSlots.first,
              );
              if (teacher.isUnavailableDuring(day: day, slot: targetSlot)) {
                continue;
              }

              // Check if current room is free and eligible at targetPeriod, or find another eligible room
              String? chosenRoomId;
              final currentRoom = activeRooms.where((r) => r.id == entry.roomId).firstOrNull;
              if (currentRoom != null &&
                  isRoomEligibleForSubject(room: currentRoom, subject: subj, section: sec) &&
                  !roomOccupancy.contains(slotKey(day, targetPeriod, entry.roomId))) {
                chosenRoomId = entry.roomId;
              } else {
                final reqCap = entry.batch != null && sec.batches.isNotEmpty
                    ? (sec.studentCount / sec.batches.length).ceil()
                    : sec.studentCount;
                for (final r in activeRooms) {
                  if (r.capacity >= reqCap &&
                      isRoomEligibleForSubject(room: r, subject: subj, section: sec) &&
                      !roomOccupancy.contains(slotKey(day, targetPeriod, r.id))) {
                    chosenRoomId = r.id;
                    break;
                  }
                }
              }

              if (chosenRoomId != null) {
                // Legally shift entry to targetPeriod
                teacherOccupancy.remove(slotKey(day, sourcePeriod, teacher.id));
                roomOccupancy.remove(slotKey(day, sourcePeriod, entry.roomId));
                sectionOccupancy.remove(slotKey(day, sourcePeriod, sec.id));

                teacherOccupancy.add(slotKey(day, targetPeriod, teacher.id));
                roomOccupancy.add(slotKey(day, targetPeriod, chosenRoomId));
                sectionOccupancy.add(slotKey(day, targetPeriod, sec.id));

                final entryIdx = scheduledEntries.indexOf(entry);
                scheduledEntries[entryIdx] = entry.copyWith(
                  periodNumber: targetPeriod,
                  timeSlotId: targetSlot.id,
                  roomId: chosenRoomId,
                );
                break;
              }
            }
          }
        }
      }
    } catch (_) {
      scheduledEntries
        ..clear()
        ..addAll(preCompactionSnapshot);
      teacherOccupancy
        ..clear()
        ..addAll(preTeacherOccSnapshot);
      roomOccupancy
        ..clear()
        ..addAll(preRoomOccSnapshot);
      sectionOccupancy
        ..clear()
        ..addAll(preSectionOccSnapshot);
    }

    stopwatch.stop();

    // 8. Verify combined result with ConflictValidator
    var allScheduleEntries = [...otherSectionEntries, ...scheduledEntries];

    var validation = ConflictValidator.validateSchedule(
      collegeId: collegeId,
      entries: allScheduleEntries,
      sections: sections,
      subjects: subjects,
      staffList: staffList,
      rooms: rooms,
      timeSlots: timeSlots,
      availabilities: availabilities,
      workingDays: days,
      validateHours: true,
      targetSectionId: targetSectionId,
    );

    if (validation.hardConflicts.isNotEmpty && preCompactionSnapshot.isNotEmpty) {
      // Revert if compaction caused any conflict
      scheduledEntries
        ..clear()
        ..addAll(preCompactionSnapshot);
      allScheduleEntries = [...otherSectionEntries, ...scheduledEntries];
      validation = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: allScheduleEntries,
        sections: sections,
        subjects: subjects,
        staffList: staffList,
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: availabilities,
        workingDays: days,
        validateHours: true,
        targetSectionId: targetSectionId,
      );
    }

    final combinedHardConflictsMap = <String, ConflictItem>{};
    for (final c in unresolvableConflicts) {
      combinedHardConflictsMap[c.id] = c;
    }
    for (final c in validation.hardConflicts) {
      combinedHardConflictsMap[c.id] = c;
    }
    final allHardConflicts = combinedHardConflictsMap.values.toList();
    final isSuccess = allHardConflicts.isEmpty;

    final distinctTeachers = scheduledEntries
        .where((e) => !e.isActivity && e.teacherId.isNotEmpty)
        .map((e) => e.teacherId)
        .toSet()
        .length;
    final distinctRooms = scheduledEntries
        .where((e) => e.roomId.isNotEmpty)
        .map((e) => e.roomId)
        .toSet()
        .length;
    final distinctSections = scheduledEntries
        .map((e) => e.sectionId)
        .toSet()
        .length;

    final targetSecName = targetSectionId != null && targetSections.isNotEmpty
        ? targetSections.first.displayName
        : null;

    final summary = isSuccess
        ? (targetSecName != null
              ? 'Timetable for $targetSecName generated successfully with 0 conflicts.'
              : 'Timetable generated successfully with 0 conflicts.')
        : (targetSecName != null
              ? 'Timetable for $targetSecName could not be completely generated. ${allHardConflicts.length} conflict(s) encountered.'
              : 'Timetable could not be completely generated. ${allHardConflicts.length} conflict(s) encountered.');

    final allConflictsMap = Map<String, ConflictItem>.from(
      combinedHardConflictsMap,
    );
    for (final w in validation.warnings) {
      allConflictsMap[w.id] = w;
    }

    return GenerationResult(
      isSuccess: isSuccess,
      versionId: versionId,
      entries: allScheduleEntries,
      newlyScheduledEntries: scheduledEntries,
      totalClassesScheduled: scheduledEntries.length,
      teachersUsed: distinctTeachers,
      roomsUsed: distinctRooms,
      sectionsScheduled: distinctSections,
      generationTimeMs: stopwatch.elapsedMilliseconds,
      conflicts: allConflictsMap.values.toList(),
      summaryMessage: summary,
      targetSectionId: targetSectionId,
    );
  }

  static ConflictItem _buildDiagnosticConflict({
    required String collegeId,
    required _ClassSessionRequest req,
    required List<String> days,
    required List<int> validPeriodNumbers,
    required List<TimeSlot> academicSlots,
    required List<Staff> authorizedTeachers,
    required List<Room> eligibleRooms,
    required Set<String> sectionOccupancy,
    required Set<String> teacherOccupancy,
    required Set<String> roomOccupancy,
    required Map<String, int> teacherDayCount,
    required List<TeacherAvailability> availabilities,
    required String Function(String, int, String) slotKey,
    required List<TimetableEntry> scheduledEntries,
    required Map<String, Subject> subjectMap,
    required Map<String, Staff> staffMap,
  }) {
    final sec = req.section;
    final subj = req.subject;
    final duration = req.durationPeriods;
    final totalSlotsChecked =
        days.length * (validPeriodNumbers.length - duration + 1);

    final rejectionReasons = <String>[];
    final reasonsCount = <String, int>{};

    for (final day in days) {
      for (var pIdx = 0; pIdx <= validPeriodNumbers.length - duration; pIdx++) {
        final periodSequence = <int>[];
        bool consecutiveValid = true;
        for (var d = 0; d < duration; d++) {
          final period = validPeriodNumbers[pIdx + d];
          if (d > 0 && period != validPeriodNumbers[pIdx + d - 1] + 1) {
            consecutiveValid = false;
            break;
          }
          periodSequence.add(period);
        }
        if (!consecutiveValid) continue;

        final pLabel = periodSequence.length == 1
            ? 'P${periodSequence.first}'
            : 'P${periodSequence.first}-P${periodSequence.last}';

        // 0. Check Subject-per-day restriction
        if (!subj.isLab) {
          final subKey = resolveSubjectKey(
            subjectId: subj.id,
            subjectMap: subjectMap,
            subjects: [],
          );
          final alreadyScheduledOnDay = scheduledEntries.any((e) =>
              e.sectionId == sec.id &&
              e.dayOfWeek == day &&
              !isLabEntry(entry: e, subjectMap: subjectMap, subjects: []) &&
              resolveSubjectKey(subjectId: e.subjectId, subjectMap: subjectMap, subjects: []) == subKey);
          if (alreadyScheduledOnDay) {
            rejectionReasons.add(
              '$day $pLabel: Subject "${subj.subjectName}" is already scheduled on this day (maximum 1 session per day)',
            );
            reasonsCount['sameDaySubject'] =
                (reasonsCount['sameDaySubject'] ?? 0) + 1;
            continue;
          }
        }

        // 1. Check Section Occupancy
        final secBusyEntries = scheduledEntries
            .where(
              (e) =>
                  e.sectionId == sec.id &&
                  e.dayOfWeek == day &&
                  periodSequence.contains(e.periodNumber) &&
                  (e.batch == null || req.batch == null || e.batch == req.batch),
            )
            .toList();
        if (secBusyEntries.isNotEmpty) {
          final clashingSubj = secBusyEntries
              .map((e) => subjectMap[e.subjectId]?.subjectName ?? e.subjectId)
              .toSet()
              .join(', ');
          rejectionReasons.add(
            '$day $pLabel: ${req.batch != null ? "Batch ${req.batch}" : "Section"} already has class ($clashingSubj)',
          );
          reasonsCount['sectionBusy'] = (reasonsCount['sectionBusy'] ?? 0) + 1;
          continue;
        }

        // 2. Check Teacher Constraints
        bool anyTeacherAvailable = false;
        String? teacherRejectReason;

        for (final teacher in authorizedTeachers) {
          final curDayCount = teacherDayCount['${day}_${teacher.id}'] ?? 0;
          if (curDayCount + duration > teacher.maxClassesPerDay) {
            teacherRejectReason =
                'Teacher ${teacher.name} daily limit reached ($curDayCount/${teacher.maxClassesPerDay})';
            reasonsCount['teacherDailyLimit'] =
                (reasonsCount['teacherDailyLimit'] ?? 0) + 1;
            continue;
          }

          bool teacherBusy = false;
          for (final p in periodSequence) {
            if (teacherOccupancy.contains(slotKey(day, p, teacher.id))) {
              final tClash = scheduledEntries
                  .where(
                    (e) =>
                        e.teacherId == teacher.id &&
                        e.dayOfWeek == day &&
                        e.periodNumber == p,
                  )
                  .firstOrNull;
              final tClashSubj = tClash != null
                  ? (subjectMap[tClash.subjectId]?.subjectName ??
                        'another section')
                  : 'another class';
              teacherRejectReason =
                  'Teacher ${teacher.name} busy with $tClashSubj';
              reasonsCount['teacherBusy'] =
                  (reasonsCount['teacherBusy'] ?? 0) + 1;
              teacherBusy = true;
              break;
            }

            final isUnavail = availabilities.any(
              (a) =>
                  a.teacherId == teacher.id &&
                  a.dayOfWeek == day &&
                  a.periodNumber == p &&
                  (!a.isAvailable || a.isLeave),
            );
            if (isUnavail) {
              teacherRejectReason =
                  'Teacher ${teacher.name} marked on leave/unavailable';
              reasonsCount['teacherLeave'] =
                  (reasonsCount['teacherLeave'] ?? 0) + 1;
              teacherBusy = true;
              break;
            }

            final matchingSlot = academicSlots.firstWhere(
              (s) => s.periodNumber == p,
              orElse: () => academicSlots.first,
            );
            if (teacher.isUnavailableDuring(day: day, slot: matchingSlot)) {
              final unavailEntry = teacher.unavailableTimes.firstWhere(
                (u) =>
                    u.dayOfWeek.toLowerCase() == day.toLowerCase() ||
                    u.dayOfWeek.toLowerCase() == 'all',
                orElse: () => UnavailableTime(
                  dayOfWeek: day,
                  startTime: matchingSlot.startTime,
                  endTime: matchingSlot.endTime,
                ),
              );
              teacherRejectReason =
                  'Teacher ${teacher.name} unavailable (${unavailEntry.startTime}-${unavailEntry.endTime})';
              reasonsCount['teacherUnavailable'] =
                  (reasonsCount['teacherUnavailable'] ?? 0) + 1;
              teacherBusy = true;
              break;
            }
          }

          if (!teacherBusy) {
            anyTeacherAvailable = true;
            break;
          }
        }

        if (!anyTeacherAvailable) {
          rejectionReasons.add(
            '$day $pLabel: ${teacherRejectReason ?? "No authorized teacher available"}',
          );
          continue;
        }

        // 3. Check Room Availability
        if (eligibleRooms.isEmpty) {
          rejectionReasons.add(
            '$day $pLabel: No compatible ${subj.isLab ? (subj.allowsClassroom ? "classroom or lab" : "lab room") : "room"} with facility "${subj.requiredRoomType}"',
          );
          reasonsCount[subj.isLab ? (subj.allowsClassroom ? 'noCompatibleRoom' : 'insufficientLabs') : 'noCompatibleRoom'] =
              (reasonsCount[subj.isLab ? (subj.allowsClassroom ? 'noCompatibleRoom' : 'insufficientLabs') : 'noCompatibleRoom'] ?? 0) + 1;
          continue;
        }

        final freeRooms = eligibleRooms
            .where(
              (r) => !periodSequence.any(
                (p) => roomOccupancy.contains(slotKey(day, p, r.id)),
              ),
            )
            .toList();
        if (freeRooms.isEmpty) {
          rejectionReasons.add('$day $pLabel: All eligible rooms occupied');
          reasonsCount['roomOccupied'] =
              (reasonsCount['roomOccupied'] ?? 0) + 1;
          continue;
        }
      }
    }

    final buffer = StringBuffer();
    buffer.writeln(
      'Cannot schedule session #${req.sessionIndex + 1} (${req.durationPeriods} hr) of ${subj.subjectName} for ${sec.displayName}${req.batch != null ? " (${req.batch})" : ""}.',
    );
    buffer.writeln();
    buffer.writeln('Candidate slots checked: $totalSlotsChecked');
    buffer.writeln('Rejected:');
    for (final reason in rejectionReasons) {
      buffer.writeln('- $reason');
    }

    String suggestion =
        'Adjust teacher availability, assign additional eligible faculty, or add available rooms.';
    if ((reasonsCount['sameDaySubject'] ?? 0) > 0) {
      suggestion =
          'Distribute sessions of "${subj.subjectName}" across different working days or configure multi-period blocks if applicable.';
    } else if ((reasonsCount['insufficientLabs'] ?? 0) > 0) {
      suggestion =
          'Timetable could not be generated because each configured batch requires its own compatible lab. Add operational labs matching facility "${subj.requiredRoomType}" with capacity >= ${(sec.studentCount / (sec.batches.isEmpty ? 1 : sec.batches.length)).ceil()}.';
    } else if ((reasonsCount['teacherUnavailable'] ?? 0) > 0 ||
        (reasonsCount['teacherDailyLimit'] ?? 0) > 0) {
      suggestion =
          'Adjust professor availability/working hours or increase daily teaching limit in Staff settings.';
    } else if ((reasonsCount['noCompatibleRoom'] ?? 0) > 0 ||
        (reasonsCount['roomOccupied'] ?? 0) > 0) {
      suggestion =
          'Add or adjust capacity for rooms of type "${subj.requiredRoomType}" to at least ${sec.studentCount}.';
    } else if ((reasonsCount['sectionBusy'] ?? 0) > 0) {
      suggestion =
          'Reduce weekly hours or add more academic periods/working days in College Settings.';
    }

    final isTeacherIssue = (reasonsCount['teacherUnavailable'] ?? 0) > 0 ||
        (reasonsCount['teacherDailyLimit'] ?? 0) > 0 ||
        (reasonsCount['noAssignedTeacher'] ?? 0) > 0;
    final isLabIssue = (reasonsCount['insufficientLabs'] ?? 0) > 0 ||
        (reasonsCount['noCompatibleRoom'] ?? 0) > 0;

    String conflictTitle;
    if (subj.isLab) {
      if (isLabIssue) {
        conflictTitle = subj.allowsClassroom
            ? 'Suitable Classroom or Lab Required'
            : 'Suitable Lab Required';
      } else if (isTeacherIssue) {
        conflictTitle = 'Teacher Unavailable for Lab';
      } else {
        conflictTitle = 'Lab Scheduling Conflict';
      }
    } else {
      conflictTitle = 'Period Scheduling Conflict';
    }

    return ConflictItem(
      id: 'diag_${subj.isLab ? "lab" : "hours"}_${sec.id}_${subj.id}_${req.sessionIndex}',
      collegeId: collegeId,
      type: subj.isLab ? 'insufficientLabs' : 'incompleteHours',
      title: conflictTitle,
      description: buffer.toString().trim(),
      subjectId: subj.id,
      sectionId: sec.id,
      suggestion: suggestion,
    );
  }
}

class _CandidatePlacement {
  final String day;
  final List<int> periodSequence;
  final Staff teacher;
  final Room room;
  final int score;

  _CandidatePlacement({
    required this.day,
    required this.periodSequence,
    required this.teacher,
    required this.room,
    required this.score,
  });

  List<Staff> get teachers => [teacher];
  List<Room> get rooms => [room];
}
