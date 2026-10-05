import '../models/models.dart';
import 'timetable_generator.dart';

class ValidationResult {
  final bool isValid;
  final List<ConflictItem> hardConflicts;
  final List<ConflictItem> warnings;

  ValidationResult({required this.hardConflicts, required this.warnings})
    : isValid = hardConflicts.isEmpty;

  List<ConflictItem> get allConflicts => [...hardConflicts, ...warnings];
}

class ConflictValidator {
  /// Validates a list of timetable entries against all constraints given the college context.
  static ValidationResult validateSchedule({
    required String collegeId,
    required List<TimetableEntry> entries,
    required List<Section> sections,
    required List<Subject> subjects,
    required List<Staff> staffList,
    required List<Room> rooms,
    required List<TimeSlot> timeSlots,
    required List<TeacherAvailability> availabilities,
    List<String>? workingDays,
    bool validateHours = false,
    String? targetSectionId,
  }) {
    final hardConflictsMap = <String, ConflictItem>{};
    final warningsMap = <String, ConflictItem>{};

    final sectionMap = {for (var s in sections) s.id: s};
    final subjectMap = {for (var s in subjects) s.id: s};
    final staffMap = {for (var s in staffList) s.id: s};
    final roomMap = {for (var r in rooms) r.id: r};

    // Filter active (non-cancelled) entries
    final rawActiveEntries = entries
        .where((e) => e.status != 'cancelled')
        .toList();

    // Check for accidental duplicate timetable entries (by identical entry ID)
    final seenEntryIds = <String>{};
    final activeEntries = <TimetableEntry>[];
    int duplicateEntryCount = 0;

    for (final entry in rawActiveEntries) {
      if (entry.id.isNotEmpty && seenEntryIds.contains(entry.id)) {
        duplicateEntryCount++;
        continue;
      }
      if (entry.id.isNotEmpty) {
        seenEntryIds.add(entry.id);
      }
      activeEntries.add(entry);
    }

    // 1. Break Collision Check
    for (final entry in activeEntries) {
      final slot = timeSlots.firstWhere(
        (t) => t.id == entry.timeSlotId || t.periodNumber == entry.periodNumber,
        orElse: () => TimeSlot(
          id: '',
          collegeId: collegeId,
          periodNumber: entry.periodNumber,
          startTime: '',
          endTime: '',
          order: 0,
        ),
      );
      if (slot.isBreak) {
        final sec = sectionMap[entry.sectionId]?.displayName ?? entry.sectionId;
        final conflictId =
            'break_${entry.sectionId}_${entry.dayOfWeek}_${entry.periodNumber}_${entry.id}';
        hardConflictsMap[conflictId] = ConflictItem(
          id: conflictId,
          collegeId: collegeId,
          type: 'breakCollisionConflict',
          severity: 'hard',
          title: 'Class Scheduled During Break',
          description:
              '$sec has a class scheduled during "${slot.label}" on ${entry.dayOfWeek}.',
          dayOfWeek: entry.dayOfWeek,
          periodNumber: entry.periodNumber,
          sectionId: entry.sectionId,
          suggestion: 'Reschedule this class to an active academic period.',
        );
      }
    }

    // 1b. Working-Day Constraints Check
    if (workingDays != null && workingDays.isNotEmpty) {
      final activeDaysSet = workingDays.toSet();
      for (final entry in activeEntries) {
        if (!activeDaysSet.contains(entry.dayOfWeek)) {
          final sec =
              sectionMap[entry.sectionId]?.displayName ?? entry.sectionId;
          final conflictId =
              'inactive_day_${entry.sectionId}_${entry.dayOfWeek}_${entry.periodNumber}_${entry.id}';
          hardConflictsMap[conflictId] = ConflictItem(
            id: conflictId,
            collegeId: collegeId,
            type: 'workingDayConflict',
            severity: 'hard',
            title: 'Class Scheduled on Inactive Working Day',
            description:
                '$sec has a class scheduled on ${entry.dayOfWeek}, which is not an active working day.',
            dayOfWeek: entry.dayOfWeek,
            periodNumber: entry.periodNumber,
            sectionId: entry.sectionId,
            suggestion: 'Reschedule this class to a configured working day.',
          );
        }
      }
    }

    // 1c. Lunch Break Constraint Check
    for (final entry in activeEntries) {
      final slot = timeSlots.firstWhere(
        (t) => t.id == entry.timeSlotId || t.periodNumber == entry.periodNumber,
        orElse: () => TimeSlot(
          id: '',
          collegeId: collegeId,
          periodNumber: entry.periodNumber,
          startTime: '',
          endTime: '',
          order: 0,
        ),
      );
      if (slot.isBreak) {
        final title = slot.breakTitle ?? '';
        final label = slot.label;
        final isLunch = title.toLowerCase().contains('lunch') ||
            label.toLowerCase().contains('lunch');
        final sec =
            sectionMap[entry.sectionId]?.displayName ?? entry.sectionId;
        final conflictId =
            'break_${entry.sectionId}_${entry.dayOfWeek}_${entry.periodNumber}_${entry.id}';
        hardConflictsMap[conflictId] = ConflictItem(
          id: conflictId,
          collegeId: collegeId,
          type: isLunch ? 'lunchCollisionConflict' : 'breakCollisionConflict',
          severity: 'hard',
          title: isLunch
              ? 'Class Scheduled During Lunch Break'
              : 'Class Scheduled During Break',
          description:
              '$sec has a class scheduled during ${isLunch ? 'lunch' : 'break'} on ${entry.dayOfWeek} at Period ${entry.periodNumber}.',
          dayOfWeek: entry.dayOfWeek,
          periodNumber: entry.periodNumber,
          sectionId: entry.sectionId,
          suggestion: 'Reschedule this class outside of break periods.',
        );
      }
    }

    // 2. Teacher Double-Booking Check
    // Map: (day, period, teacherId) -> List<TimetableEntry>
    final teacherSlotMap = <String, List<TimetableEntry>>{};
    for (final entry in activeEntries) {
      if (entry.isActivity || entry.teacherId.isEmpty) continue;
      final key = '${entry.dayOfWeek}_${entry.periodNumber}_${entry.teacherId}';
      teacherSlotMap.putIfAbsent(key, () => []).add(entry);
    }

    int rawProfDetections = 0;
    for (final entryList in teacherSlotMap.values) {
      if (entryList.length > 1) {
        rawProfDetections += (entryList.length - 1);
        final sortedEntryIds = entryList.map((e) => e.id).toList()..sort();
        final conflictId =
            'prof_${entryList.first.teacherId}_${entryList.first.dayOfWeek}_${entryList.first.periodNumber}_${sortedEntryIds.join("_")}';
        final teacher =
            staffMap[entryList.first.teacherId]?.name ?? 'Teacher';
        final secNames = entryList
            .map((e) => sectionMap[e.sectionId]?.sectionName ?? e.sectionId)
            .toSet()
            .join(' and ');
        hardConflictsMap[conflictId] = ConflictItem(
          id: conflictId,
          collegeId: collegeId,
          type: 'teacherConflict',
          severity: 'hard',
          title: 'Teacher Double-Booking',
          description:
              '$teacher is simultaneously assigned to multiple classes ($secNames) on ${entryList.first.dayOfWeek} at Period ${entryList.first.periodNumber}.',
          dayOfWeek: entryList.first.dayOfWeek,
          periodNumber: entryList.first.periodNumber,
          teacherId: entryList.first.teacherId,
          suggestion:
              'Reassign one of the classes to another qualified teacher or move to an alternative period.',
        );
      }
    }

    // 3. Room Double-Booking Check
    // Map: (day, period, roomId) -> List<TimetableEntry>
    final roomSlotMap = <String, List<TimetableEntry>>{};
    for (final entry in activeEntries) {
      if (entry.roomId.isEmpty) continue;
      final key = '${entry.dayOfWeek}_${entry.periodNumber}_${entry.roomId}';
      roomSlotMap.putIfAbsent(key, () => []).add(entry);
    }

    int rawRoomDetections = 0;
    for (final entryList in roomSlotMap.values) {
      if (entryList.length > 1) {
        rawRoomDetections += (entryList.length - 1);
        final sortedEntryIds = entryList.map((e) => e.id).toList()..sort();
        final conflictId =
            'room_${entryList.first.roomId}_${entryList.first.dayOfWeek}_${entryList.first.periodNumber}_${sortedEntryIds.join("_")}';
        final room = roomMap[entryList.first.roomId]?.roomNumber ?? 'Room';
        final secNames = entryList
            .map((e) {
              final sName = sectionMap[e.sectionId]?.sectionName ?? e.sectionId;
              if (e.isActivity) {
                final act = e.activityName?.isNotEmpty == true ? e.activityName! : 'Activity';
                return '$sName ($act)';
              }
              return e.batch != null ? '$sName (${e.batch})' : sName;
            })
            .toSet()
            .join(' and ');
        hardConflictsMap[conflictId] = ConflictItem(
          id: conflictId,
          collegeId: collegeId,
          type: 'roomConflict',
          severity: 'hard',
          title: 'Room Double-Booking',
          description:
              '$room is simultaneously assigned to multiple classes ($secNames) on ${entryList.first.dayOfWeek} at Period ${entryList.first.periodNumber}.',
          dayOfWeek: entryList.first.dayOfWeek,
          periodNumber: entryList.first.periodNumber,
          roomId: entryList.first.roomId,
          suggestion:
              'Reassign one of the classes to another available room with sufficient capacity.',
        );
      }
    }

    // 4. Section Double-Booking Check
    // Map: (day, period, sectionId) -> List<TimetableEntry>
    final sectionSlotMap = <String, List<TimetableEntry>>{};
    for (final entry in activeEntries) {
      final key = '${entry.dayOfWeek}_${entry.periodNumber}_${entry.sectionId}';
      sectionSlotMap.putIfAbsent(key, () => []).add(entry);
    }

    int rawSecDetections = 0;
    for (final entryList in sectionSlotMap.values) {
      if (entryList.length > 1) {
        // Allow simultaneous sessions for distinct batches of the section.
        final isDistinctBatches =
            entryList.length > 1 &&
            entryList.every((e) => e.batch != null) &&
            entryList.map((e) => e.batch).toSet().length == entryList.length;

        if (!isDistinctBatches) {
          rawSecDetections += (entryList.length - 1);
          final sortedEntryIds = entryList.map((e) => e.id).toList()..sort();
          final conflictId =
              'sec_${entryList.first.sectionId}_${entryList.first.dayOfWeek}_${entryList.first.periodNumber}_${sortedEntryIds.join("_")}';
          final sec =
              sectionMap[entryList.first.sectionId]?.displayName ?? 'Section';
          final subNames = entryList
              .map((e) {
                if (e.isActivity) {
                  return e.activityName?.isNotEmpty == true ? e.activityName! : 'Activity';
                }
                return subjectMap[e.subjectId]?.subjectName ?? e.subjectId;
              })
              .toSet()
              .join(' & ');
          hardConflictsMap[conflictId] = ConflictItem(
            id: conflictId,
            collegeId: collegeId,
            type: 'sectionConflict',
            severity: 'hard',
            title: 'Section Double-Booking',
            description:
                '$sec has multiple sessions scheduled ($subNames) on ${entryList.first.dayOfWeek} at Period ${entryList.first.periodNumber}.',
            dayOfWeek: entryList.first.dayOfWeek,
            periodNumber: entryList.first.periodNumber,
            sectionId: entryList.first.sectionId,
            suggestion:
                'Move one subject to a free period in the weekly schedule.',
          );
        }
      }
    }

    // 4a. Batch Double-Booking Check
    // Map: (day, period, sectionId, batch) -> List<TimetableEntry>
    final batchSlotMap = <String, List<TimetableEntry>>{};
    for (final entry in activeEntries) {
      if (entry.isActivity) continue;
      if (entry.batch != null) {
        final key =
            '${entry.dayOfWeek}_${entry.periodNumber}_${entry.sectionId}_${entry.batch}';
        batchSlotMap.putIfAbsent(key, () => []).add(entry);
      }
    }
    for (final entryList in batchSlotMap.values) {
      if (entryList.length > 1) {
        final first = entryList.first;
        final sec = sectionMap[first.sectionId]?.displayName ?? 'Section';
        final conflictId =
            'batch_double_${first.sectionId}_${first.batch}_${first.dayOfWeek}_${first.periodNumber}';
        hardConflictsMap[conflictId] = ConflictItem(
          id: conflictId,
          collegeId: collegeId,
          type: 'batchConflict',
          severity: 'hard',
          title: 'Batch Double-Booking',
          description:
              'Batch ${first.batch} of $sec is simultaneously assigned to multiple classes on ${first.dayOfWeek} at Period ${first.periodNumber}.',
          dayOfWeek: first.dayOfWeek,
          periodNumber: first.periodNumber,
          sectionId: first.sectionId,
          suggestion:
              'Ensure each batch has only one class scheduled per period.',
        );
      }
    }

    // 4b. Lab Batch Pairing and Distinct Room Integrity Check
    for (final entry in activeEntries) {
      if (entry.isActivity) continue;
      final subject = subjectMap[entry.subjectId];
      if (subject != null && subject.isLab) {
        if (entry.batch == null) {
          final conflictId =
              'lab_batch_missing_${entry.sectionId}_${entry.subjectId}_${entry.dayOfWeek}_${entry.periodNumber}_${entry.id}';
          hardConflictsMap[conflictId] = ConflictItem(
            id: conflictId,
            collegeId: collegeId,
            type: 'labBatchMissing',
            severity: 'hard',
            title: 'Lab Missing Batch Assignment',
            description:
                '${subject.subjectName} is a lab subject but is scheduled without a batch designation on ${entry.dayOfWeek} Period ${entry.periodNumber}.',
            dayOfWeek: entry.dayOfWeek,
            periodNumber: entry.periodNumber,
            sectionId: entry.sectionId,
            subjectId: entry.subjectId,
            suggestion:
                'Lab subjects must include every configured section batch simultaneously.',
          );
        } else {
          final configuredBatches =
              sectionMap[entry.sectionId]?.batches ?? const <String>[];

          final sectionSessionEntries = activeEntries
              .where(
                (e) =>
                    !e.isActivity &&
                    e.sectionId == entry.sectionId &&
                    e.dayOfWeek == entry.dayOfWeek &&
                    e.periodNumber == entry.periodNumber &&
                    subjectMap[e.subjectId]?.isLab == true,
              )
              .toList();
          final presentBatches =
              sectionSessionEntries.map((e) => e.batch).toSet();
          if (configuredBatches.isEmpty ||
              !configuredBatches.toSet().containsAll(presentBatches) ||
              presentBatches.length != sectionSessionEntries.length) {
            final conflictId =
                'lab_batches_incomplete_${entry.sectionId}_${entry.dayOfWeek}_${entry.periodNumber}';
            hardConflictsMap[conflictId] = ConflictItem(
              id: conflictId,
              collegeId: collegeId,
              type: configuredBatches.isEmpty
                  ? 'missingLabBatches'
                  : 'duplicateBatchInSlot',
              severity: 'hard',
              title: configuredBatches.isEmpty
                  ? 'Lab Batches Not Configured'
                  : 'Duplicate Batch In Same Slot',
              description:
                  'Lab session on ${entry.dayOfWeek} Period ${entry.periodNumber} has invalid batch assignment.',
              dayOfWeek: entry.dayOfWeek,
              periodNumber: entry.periodNumber,
              sectionId: entry.sectionId,
              subjectId: entry.subjectId,
              suggestion:
                  'Ensure configured section batches are uniquely assigned.',
            );
          } else {
            // If parallel batches are in distinct compatible rooms, sharing the same lab subject
            // is valid (e.g. a 60-student section split across two 30-seat labs).
            // Only flag if batches are assigned to the same room.
            if (sectionSessionEntries
                    .map((e) => e.roomId)
                    .toSet()
                    .length !=
                sectionSessionEntries.length) {
              final room = roomMap[entry.roomId]?.roomNumber ?? 'Room';
              final conflictId =
                  'lab_same_room_${entry.sectionId}_${entry.roomId}_${entry.dayOfWeek}_${entry.periodNumber}';
              hardConflictsMap[conflictId] = ConflictItem(
                id: conflictId,
                collegeId: collegeId,
                type: 'labSameRoomConflict',
                severity: 'hard',
                title: 'Batches Sharing Same Lab',
                description:
                    'Parallel batches for ${sectionMap[entry.sectionId]?.displayName ?? 'Section'} share room $room on ${entry.dayOfWeek} Period ${entry.periodNumber}. Each batch requires a distinct compatible lab.',
                dayOfWeek: entry.dayOfWeek,
                periodNumber: entry.periodNumber,
                roomId: entry.roomId,
                sectionId: entry.sectionId,
                subjectId: entry.subjectId,
                suggestion:
                    'Assign each configured batch to a different suitable lab.',
              );
            }
          }
        }
      }
    }

    // 4b-2. Explicit Check (Requirement 14):
    // SAME_SECTION + SAME_LAB_SUBJECT + DIFFERENT_BATCHES occupying the same physical lab and same time.
    final labBatchRoomEntries = <String, List<TimetableEntry>>{};
    for (final entry in activeEntries) {
      if (entry.isActivity) continue;
      if (entry.batch != null && subjectMap[entry.subjectId]?.isLab == true) {
        final key =
            '${entry.sectionId}_${entry.subjectId}_${entry.roomId}_${entry.dayOfWeek}_${entry.periodNumber}';
        (labBatchRoomEntries[key] ??= []).add(entry);
      }
    }
    for (final slotEntries in labBatchRoomEntries.values) {
      final distinctBatches = slotEntries.map((e) => e.batch).toSet();
      if (distinctBatches.length > 1) {
        final first = slotEntries.first;
        final room = roomMap[first.roomId]?.roomNumber ?? 'Room';
        final sub = subjectMap[first.subjectId]?.subjectName ?? 'Lab';
        final sec = sectionMap[first.sectionId]?.displayName ?? 'Section';
        final batchesStr = distinctBatches.join(' and ');
        final conflictId =
            'lab_same_room_batches_${first.sectionId}_${first.subjectId}_${first.roomId}_${first.dayOfWeek}_${first.periodNumber}';
        hardConflictsMap[conflictId] = ConflictItem(
          id: conflictId,
          collegeId: collegeId,
          type: 'labSameRoomConflict',
          severity: 'hard',
          title: 'Batches Sharing Same Lab Room',
          description:
              'Batches $batchesStr of $sub for $sec are scheduled simultaneously in the same physical lab ($room) on ${first.dayOfWeek} Period ${first.periodNumber}.',
          dayOfWeek: first.dayOfWeek,
          periodNumber: first.periodNumber,
          roomId: first.roomId,
          sectionId: first.sectionId,
          subjectId: first.subjectId,
          suggestion:
              'Schedule batches at different times or assign each batch to a different physical lab.',
        );
      }
    }

    // 4c. Enforce configured lab block duration
    final orderedSlots = [...timeSlots]
      ..sort((a, b) => a.order.compareTo(b.order));

    // Check consecutive periods for each individual lab session (by section, subject, batch, day)
    final individualLabSessions = <String, List<TimetableEntry>>{};
    for (final entry in activeEntries) {
      if (entry.isActivity) continue;
      if (subjectMap[entry.subjectId]?.isLab == true) {
        final key =
            '${entry.sectionId}_${entry.subjectId}_${entry.batch}_${entry.dayOfWeek}';
        individualLabSessions.putIfAbsent(key, () => []).add(entry);
      }
    }
    for (final sessionEntries in individualLabSessions.values) {
      final subject = subjectMap[sessionEntries.first.subjectId]!;
      final duration =
          subject.consecutivePeriods < 1 ? 1 : subject.consecutivePeriods;
      final periods = sessionEntries.map((e) => e.periodNumber).toSet().toList()
        ..sort();
      var runLength = 1;
      var invalidBlock = false;
      for (var i = 1; i < periods.length; i++) {
        final prevIndex = orderedSlots.indexWhere(
          (slot) => !slot.isBreak && slot.periodNumber == periods[i - 1],
        );
        final currentIndex = orderedSlots.indexWhere(
          (slot) => !slot.isBreak && slot.periodNumber == periods[i],
        );
        if (periods[i] == periods[i - 1] + 1 && currentIndex == prevIndex + 1) {
          runLength++;
        } else {
          if (runLength % duration != 0) invalidBlock = true;
          runLength = 1;
        }
      }
      if (runLength % duration != 0) invalidBlock = true;
      if (invalidBlock) {
        final entry = sessionEntries.first;
        final conflictId =
            'lab_duration_${entry.sectionId}_${entry.subjectId}_${entry.batch}_${entry.dayOfWeek}';
        hardConflictsMap[conflictId] = ConflictItem(
          id: conflictId,
          collegeId: collegeId,
          type: 'labDurationConflict',
          severity: 'hard',
          title: 'Lab Block Is Not Consecutive',
          description:
              '${subject.subjectName} (${entry.batch}) requires blocks of $duration consecutive periods on ${entry.dayOfWeek}.',
          sectionId: entry.sectionId,
          subjectId: entry.subjectId,
          dayOfWeek: entry.dayOfWeek,
          suggestion: 'Move the batch into complete consecutive lab blocks.',
        );
      }
    }

    // 4d. Same-Day Subject Repetition Check (Core Rule: at most 1 theory session per day per section)
    // Group active entries by section, then by day, then by canonical subject key.
    // Labs occupying multiple consecutive periods represent ONE lab session and are exempted.
    final sectionDaySubjectEntries = <String, List<TimetableEntry>>{};
    for (final entry in activeEntries) {
      if (entry.isActivity || entry.subjectId.isEmpty) {
        continue;
      }
      if (targetSectionId != null && entry.sectionId != targetSectionId) {
        continue;
      }
      if (sections.isNotEmpty && !sectionMap.containsKey(entry.sectionId)) {
        continue;
      }
      if (!TimetableGenerator.isLabEntry(
        entry: entry,
        subjectMap: subjectMap,
        subjects: subjects,
      )) {
        final subKey = TimetableGenerator.resolveSubjectKey(
          subjectId: entry.subjectId,
          subjectMap: subjectMap,
          subjects: subjects,
        );
        final key = '${entry.sectionId}_${entry.dayOfWeek}_$subKey';
        sectionDaySubjectEntries.putIfAbsent(key, () => []).add(entry);
      }
    }

    for (final entryList in sectionDaySubjectEntries.values) {
      final distinctPeriods =
          entryList.map((e) => e.periodNumber).toSet().toList()..sort();
      if (distinctPeriods.length > 1) {
        final first = entryList.first;
        final subObj = TimetableGenerator.findSubject(
          subjectId: first.subjectId,
          subjectMap: subjectMap,
          subjects: subjects,
        );
        final subName = subObj?.subjectName.isNotEmpty == true
            ? subObj!.subjectName
            : first.subjectId;
        final secName =
            sectionMap[first.sectionId]?.displayName ?? first.sectionId;
        final subKey = TimetableGenerator.resolveSubjectKey(
          subjectId: first.subjectId,
          subjectMap: subjectMap,
          subjects: subjects,
        );
        final conflictId =
            'subject_rep_${first.sectionId}_${subKey}_${first.dayOfWeek}';

        hardConflictsMap[conflictId] = ConflictItem(
          id: conflictId,
          collegeId: collegeId,
          type: 'sameDaySubjectConflict',
          severity: 'hard',
          title: 'Subject Scheduled Multiple Times in One Day',
          description:
              '$secName has multiple theory sessions (${distinctPeriods.length}) of "$subName" scheduled on ${first.dayOfWeek} at Periods ${distinctPeriods.join(", ")}. A theory/regular subject may have at most one scheduled session per day.',
          dayOfWeek: first.dayOfWeek,
          periodNumber: distinctPeriods.first,
          sectionId: first.sectionId,
          subjectId: subObj?.id ?? first.subjectId,
          suggestion:
              'Distribute sessions of "$subName" across different working days.',
        );
      }
    }

    // 5. Room Capacity Check
    for (final entry in activeEntries) {
      if (entry.roomId.isEmpty) continue;
      final section = sectionMap[entry.sectionId];
      final room = roomMap[entry.roomId];
      if (section != null && room != null) {
        final requiredCapacity = entry.batch != null
            ? (section.studentCount /
                      (section.batches.isEmpty ? 1 : section.batches.length))
                  .ceil()
            : section.studentCount;
        if (room.capacity < requiredCapacity) {
          final label = entry.batch != null
              ? '${section.displayName} (${entry.batch})'
              : section.displayName;
          final conflictId =
              'capacity_${entry.roomId}_${entry.sectionId}_${entry.dayOfWeek}_${entry.periodNumber}_${entry.id}';
          hardConflictsMap[conflictId] = ConflictItem(
            id: conflictId,
            collegeId: collegeId,
            type: 'capacityConflict',
            severity: 'hard',
            title: 'Room Capacity Insufficient',
            description:
                '${room.roomNumber} (Capacity: ${room.capacity}) cannot accommodate $label (Students: $requiredCapacity) on ${entry.dayOfWeek} Period ${entry.periodNumber}.',
            dayOfWeek: entry.dayOfWeek,
            periodNumber: entry.periodNumber,
            roomId: room.id,
            sectionId: section.id,
            suggestion:
                'Assign a larger room with capacity >= $requiredCapacity.',
          );
        }
      }
    }

    // 6. Room Type / Facility Compatibility Check
    for (final entry in activeEntries) {
      if (entry.isActivity || entry.subjectId.isEmpty || entry.roomId.isEmpty) continue;
      final subject = subjectMap[entry.subjectId];
      final room = roomMap[entry.roomId];
      final section = sectionMap[entry.sectionId];
      if (subject != null && room != null) {
        final isEligible = TimetableGenerator.isRoomEligibleForSubject(
          room: room,
          subject: subject,
          section: section,
        );

        if (!isEligible) {
          final conflictId =
              'room_type_${entry.roomId}_${entry.subjectId}_${entry.dayOfWeek}_${entry.periodNumber}_${entry.id}';
          hardConflictsMap[conflictId] = ConflictItem(
            id: conflictId,
            collegeId: collegeId,
            type: 'roomTypeMismatch',
            severity: 'hard',
            title: 'Incompatible Room Type',
            description:
                '${subject.subjectName} requires a compatible "${subject.requiredRoomType}" but is scheduled in ${room.roomNumber} (${room.roomType}).',
            dayOfWeek: entry.dayOfWeek,
            periodNumber: entry.periodNumber,
            roomId: room.id,
            subjectId: subject.id,
            suggestion: 'Assign to a designated ${subject.requiredRoomType}.',
          );
        }
      }
    }

    // 7. Teacher Authorization & Eligibility Check
    for (final entry in activeEntries) {
      if (entry.isActivity || entry.teacherId.isEmpty) continue;
      final teacher = staffMap[entry.teacherId];
      final subject = subjectMap[entry.subjectId];
      if (teacher != null && (!teacher.active || teacher.status == 'inactive')) {
        final conflictId =
            'teacher_inactive_${entry.teacherId}_${entry.dayOfWeek}_${entry.periodNumber}_${entry.id}';
        hardConflictsMap[conflictId] = ConflictItem(
          id: conflictId,
          collegeId: collegeId,
          type: 'inactiveTeacherConflict',
          severity: 'hard',
          title: 'Inactive Teacher Assigned',
          description:
              '${teacher.name} is marked inactive but is assigned a class on ${entry.dayOfWeek} Period ${entry.periodNumber}.',
          dayOfWeek: entry.dayOfWeek,
          periodNumber: entry.periodNumber,
          teacherId: teacher.id,
          suggestion: 'Reassign to an active faculty member.',
        );
      }
      if (teacher != null && subject != null) {
        final isEligible = teacher.isEligibleForSubject(
          subjectName: subject.subjectName,
          subjectCode: subject.subjectCode,
          courseShortName: subject.courseShortName,
          subjectId: subject.id,
        );
        final isAuthorized =
            isEligible &&
            (subject.assignedTeacherIds.isEmpty ||
                subject.assignedTeacherIds.contains(teacher.id));
        if (!isAuthorized) {
          final conflictId =
              'unauth_${entry.teacherId}_${entry.subjectId}_${entry.dayOfWeek}_${entry.periodNumber}_${entry.id}';
          hardConflictsMap[conflictId] = ConflictItem(
            id: conflictId,
            collegeId: collegeId,
            type: 'unauthorizedTeacher',
            severity: 'hard',
            title: 'Ineligible Teacher Assignment',
            description:
                '${teacher.name} is not eligible to teach ${subject.subjectName} (${subject.subjectCode}) according to their "Can Teach" configuration.',
            dayOfWeek: entry.dayOfWeek,
            periodNumber: entry.periodNumber,
            teacherId: teacher.id,
            subjectId: subject.id,
            suggestion:
                'Assign an eligible professor configured for ${subject.subjectName}.',
          );
        }
      }
    }

    // 8. Teacher Availability & Leave Check
    for (final entry in activeEntries) {
      if (entry.isActivity || entry.teacherId.isEmpty) continue;
      final teacher = staffMap[entry.teacherId];
      final unavail = availabilities
          .where(
            (a) =>
                a.teacherId == entry.teacherId &&
                a.dayOfWeek == entry.dayOfWeek &&
                a.periodNumber == entry.periodNumber &&
                (!a.isAvailable || a.isLeave),
          )
          .toList();

      if (unavail.isNotEmpty) {
        final record = unavail.first;
        final reason = record.leaveReason?.isNotEmpty == true
            ? ' (${record.leaveReason})'
            : '';
        final conflictId =
            'avail_${entry.teacherId}_${entry.dayOfWeek}_${entry.periodNumber}_${entry.id}';
        hardConflictsMap[conflictId] = ConflictItem(
          id: conflictId,
          collegeId: collegeId,
          type: 'availabilityConflict',
          severity: 'hard',
          title: 'Teacher Unavailable / On Leave',
          description:
              '${teacher?.name ?? 'Teacher'} is marked unavailable on ${entry.dayOfWeek} Period ${entry.periodNumber}$reason.',
          dayOfWeek: entry.dayOfWeek,
          periodNumber: entry.periodNumber,
          teacherId: entry.teacherId,
          suggestion:
              'Reassign to a substitute faculty member or swap to an available period.',
        );
      } else if (teacher != null) {
        final slot = timeSlots.firstWhere(
          (s) => s.id == entry.timeSlotId,
          orElse: () => timeSlots.firstWhere(
            (s) =>
                s.periodNumber == entry.periodNumber &&
                (s.dayOfWeek == null ||
                    s.dayOfWeek == 'ALL' ||
                    s.dayOfWeek == entry.dayOfWeek),
            orElse: () => TimeSlot(
              id: '',
              collegeId: collegeId,
              periodNumber: entry.periodNumber,
              startTime: '',
              endTime: '',
              order: entry.periodNumber,
            ),
          ),
        );
        if (teacher.isUnavailableDuring(day: entry.dayOfWeek, slot: slot)) {
          final conflictId =
              'avail_time_${entry.teacherId}_${entry.dayOfWeek}_${entry.periodNumber}_${entry.id}';
          hardConflictsMap[conflictId] = ConflictItem(
            id: conflictId,
            collegeId: collegeId,
            type: 'availabilityConflict',
            severity: 'hard',
            title: 'Teacher Unavailable',
            description:
                '${teacher.name} is marked unavailable on ${entry.dayOfWeek} during ${slot.timeRange.isNotEmpty ? slot.timeRange : 'Period ${entry.periodNumber}'}.',
            dayOfWeek: entry.dayOfWeek,
            periodNumber: entry.periodNumber,
            teacherId: entry.teacherId,
            suggestion:
                'Reassign to a substitute faculty member or swap to an available period.',
          );
        }
      }
    }

    // 9. Room Maintenance Check
    for (final entry in activeEntries) {
      if (entry.roomId.isEmpty) continue;
      final room = roomMap[entry.roomId];
      if (room != null && room.isUnderMaintenance) {
        final reason = room.maintenanceReason?.isNotEmpty == true
            ? ' (${room.maintenanceReason})'
            : '';
        final conflictId =
            'maint_${entry.roomId}_${entry.dayOfWeek}_${entry.periodNumber}_${entry.id}';
        hardConflictsMap[conflictId] = ConflictItem(
          id: conflictId,
          collegeId: collegeId,
          type: 'roomMaintenanceConflict',
          severity: 'hard',
          title: 'Room Under Maintenance',
          description:
              '${room.roomNumber} is currently undergoing maintenance$reason and cannot host classes.',
          dayOfWeek: entry.dayOfWeek,
          periodNumber: entry.periodNumber,
          roomId: room.id,
          suggestion: 'Transfer scheduled classes to an operational room.',
        );
      }
    }

    // 10. Teacher Maximum Classes Per Day Check
    final teacherDayCount = <String, Set<int>>{};
    for (final entry in activeEntries) {
      if (entry.isActivity || entry.teacherId.isEmpty) continue;
      final key = '${entry.dayOfWeek}_${entry.teacherId}';
      teacherDayCount.putIfAbsent(key, () => <int>{}).add(entry.periodNumber);
    }
    for (final entry in teacherDayCount.entries) {
      final parts = entry.key.split('_');
      final day = parts[0];
      final teacherId = parts[1];
      final teacher = staffMap[teacherId];
      final maxAllowed = teacher?.maxClassesPerDay ?? 4;
      if (entry.value.length > maxAllowed) {
        final conflictId = 'max_classes_${teacherId}_$day';
        hardConflictsMap[conflictId] = ConflictItem(
          id: conflictId,
          collegeId: collegeId,
          type: 'maxClassesPerDayExceeded',
          severity: 'hard',
          title: 'Teacher Daily Limit Exceeded',
          description:
              '${teacher?.name ?? 'Teacher'} is scheduled for ${entry.value.length} classes on $day (Configured Max: $maxAllowed).',
          dayOfWeek: day,
          teacherId: teacherId,
          suggestion: 'Redistribute load across other working days.',
        );
      }
    }

    // 11. Incomplete Hours Check (Subject, Lab, and Batch Requirements)
    if (validateHours) {
      final targetSectionsToCheck = targetSectionId != null
          ? sections.where((s) => s.id == targetSectionId && s.active).toList()
          : sections.where((s) => s.active).toList();

      for (final sec in targetSectionsToCheck) {
        final secSubjects = subjects.where((s) {
          if (!s.active) return false;
          if (s.sectionId != null && s.sectionId!.isNotEmpty) {
            return s.sectionId == sec.id;
          }
          return s.semester == sec.semester && s.departmentId == sec.departmentId;
        }).toList();

        for (final subj in secSubjects) {
          if (!subj.isLab) {
            // Theory: check total scheduled hours for this section
            final scheduledCount = activeEntries
                .where((e) => !e.isActivity && e.sectionId == sec.id && e.subjectId == subj.id)
                .length;
            if (scheduledCount < subj.hoursPerWeek) {
              final conflictId = 'incomplete_theory_${sec.id}_${subj.id}';
              hardConflictsMap[conflictId] = ConflictItem(
                id: conflictId,
                collegeId: collegeId,
                type: 'incompleteHours',
                severity: 'hard',
                title: 'Incomplete Subject Hours',
                description:
                    '${sec.displayName} requires ${subj.hoursPerWeek} weekly hours for ${subj.subjectName}, but only $scheduledCount were scheduled.',
                sectionId: sec.id,
                subjectId: subj.id,
                suggestion:
                    'Ensure sufficient period slots and faculty availability.',
              );
            }
          } else {
            // Lab: check each configured batch
            final batches = sec.batches;
            final blockDur =
                subj.consecutivePeriods >= 2 ? subj.consecutivePeriods : 2;
            int reqHoursPerBatch;
            if (batches.isEmpty) {
              reqHoursPerBatch = subj.hoursPerWeek;
            } else if (subj.hoursPerWeek >= blockDur * batches.length) {
              final totalSessions =
                  (subj.hoursPerWeek / blockDur).round().clamp(1, 20);
              final sessionsPerBatch =
                  (totalSessions / batches.length).round().clamp(1, 10);
              reqHoursPerBatch = sessionsPerBatch * blockDur;
            } else {
              final totalSessions =
                  (subj.hoursPerWeek / blockDur).round().clamp(1, 20);
              reqHoursPerBatch = totalSessions * blockDur;
            }

            if (batches.isEmpty) {
              final scheduledCount = activeEntries
                  .where((e) => !e.isActivity && e.sectionId == sec.id && e.subjectId == subj.id)
                  .length;
              if (scheduledCount < reqHoursPerBatch) {
                final conflictId = 'incomplete_lab_${sec.id}_${subj.id}';
                hardConflictsMap[conflictId] = ConflictItem(
                  id: conflictId,
                  collegeId: collegeId,
                  type: 'incompleteHours',
                  severity: 'hard',
                  title: 'Incomplete Lab Hours',
                  description:
                      '${sec.displayName} requires $reqHoursPerBatch hours for ${subj.subjectName}, but only $scheduledCount were scheduled.',
                  sectionId: sec.id,
                  subjectId: subj.id,
                  suggestion:
                      'Configure section batches and ensure compatible labs are available.',
                );
              }
            } else {
              for (final b in batches) {
                final scheduledBatchHours = activeEntries
                    .where((e) =>
                        !e.isActivity &&
                        e.sectionId == sec.id &&
                        e.subjectId == subj.id &&
                        e.batch == b)
                    .length;
                if (scheduledBatchHours < reqHoursPerBatch) {
                  final conflictId =
                      'incomplete_batch_lab_${sec.id}_${subj.id}_$b';
                  hardConflictsMap[conflictId] = ConflictItem(
                    id: conflictId,
                    collegeId: collegeId,
                    type: 'incompleteHours',
                    severity: 'hard',
                    title: 'Incomplete Batch Lab Hours',
                    description:
                        'Batch $b of ${sec.displayName} requires $reqHoursPerBatch hours for ${subj.subjectName}, but only $scheduledBatchHours were scheduled.',
                    sectionId: sec.id,
                    subjectId: subj.id,
                    suggestion:
                        'Ensure compatible labs and faculty are available for all batches.',
                  );
                }
              }
            }
          }
        }
      }
    }

    final uniqueProfCount = hardConflictsMap.values
        .where((c) => c.type == 'teacherConflict')
        .length;
    final uniqueSecCount = hardConflictsMap.values
        .where((c) => c.type == 'sectionConflict')
        .length;
    final uniqueRoomCount = hardConflictsMap.values
        .where((c) => c.type == 'roomConflict')
        .length;
    final uniqueSubjectRepCount = hardConflictsMap.values
        .where((c) => c.type == 'sameDaySubjectConflict')
        .length;

    // Temporary debug logging (Requirement 9)
    // ignore: avoid_print
    print('================ CONSTRAINT VALIDATION DEBUG ================');
    // ignore: avoid_print
    print('TIMETABLE ENTRIES: ${entries.length}');
    // ignore: avoid_print
    print('UNIQUE TIMETABLE ENTRIES: ${activeEntries.length}');
    // ignore: avoid_print
    print('DUPLICATE ENTRIES FILTERED: $duplicateEntryCount');
    // ignore: avoid_print
    print('PROFESSOR CONFLICTS:');
    // ignore: avoid_print
    print('  Raw detections: $rawProfDetections');
    // ignore: avoid_print
    print('  Unique conflicts: $uniqueProfCount');
    // ignore: avoid_print
    print('SECTION CONFLICTS:');
    // ignore: avoid_print
    print('  Raw detections: $rawSecDetections');
    // ignore: avoid_print
    print('  Unique conflicts: $uniqueSecCount');
    // ignore: avoid_print
    print('ROOM CONFLICTS:');
    // ignore: avoid_print
    print('  Raw detections: $rawRoomDetections');
    // ignore: avoid_print
    print('  Unique conflicts: $uniqueRoomCount');
    // ignore: avoid_print
    print('SAME-DAY SUBJECT CONFLICTS:');
    // ignore: avoid_print
    print('  Unique conflicts: $uniqueSubjectRepCount');
    // ignore: avoid_print
    print('=============================================================');

    return ValidationResult(
      hardConflicts: hardConflictsMap.values.toList(),
      warnings: warningsMap.values.toList(),
    );
  }

  /// Validates whether proposed entries (single class or multi-period lab block) will introduce conflicts
  static ValidationResult validateProposedEntries({
    required String collegeId,
    required List<TimetableEntry> proposedEntries,
    required List<TimetableEntry> existingEntries,
    required List<Section> sections,
    required List<Subject> subjects,
    required List<Staff> staffList,
    required List<Room> rooms,
    required List<TimeSlot> timeSlots,
    required List<TeacherAvailability> availabilities,
    List<String>? workingDays,
  }) {
    final proposedIds = proposedEntries.map((e) => e.id).toSet();
    final simulated = existingEntries
        .where((e) => !proposedIds.contains(e.id))
        .toList();
    simulated.addAll(proposedEntries);

    return validateSchedule(
      collegeId: collegeId,
      entries: simulated,
      sections: sections,
      subjects: subjects,
      staffList: staffList,
      rooms: rooms,
      timeSlots: timeSlots,
      availabilities: availabilities,
      workingDays: workingDays,
    );
  }

  /// Validates whether a proposed single edit (add/move/change teacher/change room) will introduce conflicts
  static ValidationResult validateSingleEntry({
    required String collegeId,
    required TimetableEntry proposedEntry,
    required List<TimetableEntry> existingEntries,
    required List<Section> sections,
    required List<Subject> subjects,
    required List<Staff> staffList,
    required List<Room> rooms,
    required List<TimeSlot> timeSlots,
    required List<TeacherAvailability> availabilities,
    List<String>? workingDays,
  }) {
    return validateProposedEntries(
      collegeId: collegeId,
      proposedEntries: [proposedEntry],
      existingEntries: existingEntries,
      sections: sections,
      subjects: subjects,
      staffList: staffList,
      rooms: rooms,
      timeSlots: timeSlots,
      availabilities: availabilities,
      workingDays: workingDays,
    );
  }

  /// Finds alternative available teachers for an affected slot
  static List<Staff> findReplacementTeachers({
    required String collegeId,
    required String subjectId,
    required String dayOfWeek,
    required int periodNumber,
    required List<Staff> allStaff,
    required List<Subject> allSubjects,
    required List<TimetableEntry> activeEntries,
    required List<TeacherAvailability> availabilities,
    List<TimeSlot>? timeSlots,
    String? excludeTeacherId,
  }) {
    final subject = allSubjects.firstWhere(
      (s) => s.id == subjectId,
      orElse: () => Subject(
        id: '',
        collegeId: collegeId,
        departmentId: '',
        courseId: '',
        semester: 1,
        subjectCode: '',
        subjectName: '',
      ),
    );

    return allStaff.where((teacher) {
      if (teacher.id == excludeTeacherId) return false;
      if (!teacher.active || teacher.status == 'inactive') return false;

      // 1. Must be eligible and authorized for this subject
      final isEligible = teacher.isEligibleForSubject(
        subjectName: subject.subjectName,
        subjectCode: subject.subjectCode,
        courseShortName: subject.courseShortName,
        subjectId: subject.id,
      );
      final isAuthorized =
          isEligible &&
          (subject.assignedTeacherIds.isEmpty ||
              subject.assignedTeacherIds.contains(teacher.id));
      if (!isAuthorized) return false;

      // 2. Check if already teaching another class at this day and period
      final hasClass = activeEntries.any(
        (e) =>
            e.teacherId == teacher.id &&
            e.dayOfWeek == dayOfWeek &&
            e.periodNumber == periodNumber &&
            e.status != 'cancelled',
      );
      if (hasClass) return false;

      // 3. Check teacher availability/leave
      final isUnavailable = availabilities.any(
        (a) =>
            a.teacherId == teacher.id &&
            a.dayOfWeek == dayOfWeek &&
            a.periodNumber == periodNumber &&
            (!a.isAvailable || a.isLeave),
      );
      if (isUnavailable) return false;

      final slot = (timeSlots ?? []).firstWhere(
        (s) =>
            s.periodNumber == periodNumber &&
            (s.dayOfWeek == null ||
                s.dayOfWeek == 'ALL' ||
                s.dayOfWeek == dayOfWeek),
        orElse: () => TimeSlot(
          id: '',
          collegeId: collegeId,
          periodNumber: periodNumber,
          startTime: '',
          endTime: '',
          order: periodNumber,
        ),
      );
      if (teacher.isUnavailableDuring(day: dayOfWeek, slot: slot)) return false;

      return true;
    }).toList();
  }

  /// Finds alternative available rooms for an affected slot
  static List<Room> findAlternativeRooms({
    required String collegeId,
    required String subjectId,
    required int studentCount,
    required String dayOfWeek,
    required int periodNumber,
    required List<Room> allRooms,
    required List<Subject> allSubjects,
    required List<TimetableEntry> activeEntries,
    String? excludeRoomId,
    bool isBatch = false,
    int batchCount = 1,
  }) {
    final subject = allSubjects.firstWhere(
      (s) => s.id == subjectId,
      orElse: () => Subject(
        id: '',
        collegeId: collegeId,
        departmentId: '',
        courseId: '',
        semester: 1,
        subjectCode: '',
        subjectName: '',
      ),
    );

    final neededCapacity = isBatch
        ? (studentCount / (batchCount < 1 ? 1 : batchCount)).ceil()
        : studentCount;

    return allRooms.where((room) {
      if (room.id == excludeRoomId) return false;
      if (!room.active || room.isUnderMaintenance) return false;

      // 1. Capacity >= section student count (or batch count)
      if (room.capacity < neededCapacity) return false;

      // 2. Room type / facility compatibility
      if (subject.isLab) {
        if (!TimetableGenerator.isRoomEligibleForSubject(room: room, subject: subject)) {
          return false;
        }
      } else {
        final req = subject.requiredRoomType.trim().toLowerCase();
        final matches =
            req.isEmpty ||
            req == 'classroom' ||
            room.roomType.trim().toLowerCase() == req ||
            room.facilities.any((f) => f.trim().toLowerCase() == req);
        if (!matches) {
          return false;
        }
      }

      // 3. Not booked at this slot
      final isOccupied = activeEntries.any(
        (e) =>
            e.roomId == room.id &&
            e.dayOfWeek == dayOfWeek &&
            e.periodNumber == periodNumber &&
            e.status != 'cancelled',
      );
      if (isOccupied) return false;

      return true;
    }).toList();
  }
}
