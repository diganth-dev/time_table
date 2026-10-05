import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../features/timetable/timetable_utils.dart';
import '../models/models.dart';

/// Service for generating read-only, local PDF documents for timetables.
///
/// FIRESTORE SAFETY:
/// This service is 100% READ-ONLY. It receives in-memory model instances
/// and performs ZERO Firestore reads, writes, updates, deletes, or mutations.
class PdfExportService {
  /// Generates a PDF document in memory and returns raw bytes.
  static Future<Uint8List> generateTimetablePdf({
    required PdfPageFormat pageFormat,
    required College? college,
    required TimetableVersion? version,
    required List<TimetableEntry> entries,
    required List<TimeSlot> timeSlots,
    required Map<String, Staff> staffMap,
    required Map<String, Section> sectionMap,
    required Map<String, Room> roomMap,
    required Map<String, Subject> subjectMap,
    required String targetView, // 'section', 'teacher', 'course', 'room', or 'master'
    String? selectedSectionId,
    String? selectedTeacherId,
    String? selectedSubjectId,
    String? selectedRoomId,
    List<String>? workingDays,
    bool compress = true,
  }) async {
    final pdf = pw.Document(
      title: '${college?.name ?? "Timetable"} - Export',
      author: 'Timetable Assistant',
      compress: compress,
    );

    final fontBase = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();
    final theme = pw.ThemeData.withFont(base: fontBase, bold: fontBold);

    final days = workingDays ??
        college?.workingDays ??
        const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

    final academicSlots = timeSlots.where((t) => !t.isBreak).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final allOrderedSlots = [...timeSlots]..sort((a, b) => a.order.compareTo(b.order));

    if (targetView == 'section') {
      final targetSections = selectedSectionId != null
          ? [?sectionMap[selectedSectionId]]
          : sectionMap.values.toList();
      for (final sec in targetSections) {
        final secEntries = entries.where((e) => e.sectionId == sec.id).toList();
        pdf.addPage(
          _buildTimetablePage(
            theme: theme,
            pageFormat: pageFormat,
            college: college,
            version: version,
            title: 'Section: ${sec.displayName}',
            subtitle: 'Academic Year: ${college?.academicYear ?? "Current"} | Students: ${sec.studentCount} | Batches: ${sec.batches.isEmpty ? "None" : sec.batches.join(", ")}',
            days: days,
            allSlots: allOrderedSlots,
            academicSlots: academicSlots,
            entries: secEntries,
            staffMap: staffMap,
            sectionMap: sectionMap,
            roomMap: roomMap,
            subjectMap: subjectMap,
            viewMode: 'section',
            targetSection: sec,
          ),
        );
      }
    } else if (targetView == 'teacher') {
      final targetStaff = selectedTeacherId != null
          ? [?staffMap[selectedTeacherId]]
          : staffMap.values.toList();
      for (final teacher in targetStaff) {
        final teacherEntries = entries.where((e) => e.teacherId == teacher.id).toList();
        final workload = calculateProfessorWorkload(
          teacher: teacher,
          allSubjects: subjectMap.values.toList(),
          sectionMap: sectionMap,
          entries: entries,
          subjectMap: subjectMap,
        );

        pdf.addPage(
          _buildTimetablePage(
            theme: theme,
            pageFormat: pageFormat,
            college: college,
            version: version,
            title: 'Faculty: ${teacher.name}',
            subtitle: 'Dept: ${teacher.departmentId} | Required: ${workload.requiredWorkload}h | Scheduled: ${workload.scheduledTotal}h (Theory: ${workload.scheduledTheory}h, Lab: ${workload.scheduledLab}h) | Remaining: ${workload.remaining}h',
            days: days,
            allSlots: allOrderedSlots,
            academicSlots: academicSlots,
            entries: teacherEntries,
            staffMap: staffMap,
            sectionMap: sectionMap,
            roomMap: roomMap,
            subjectMap: subjectMap,
            viewMode: 'teacher',
          ),
        );
      }
    } else if (targetView == 'course') {
      final targetSubjects = selectedSubjectId != null
          ? [?subjectMap[selectedSubjectId]]
          : subjectMap.values.toList();
      for (final sub in targetSubjects) {
        final courseEntries = entries.where((e) => e.subjectId == sub.id).toList();
        pdf.addPage(
          _buildCoursePage(
            theme: theme,
            pageFormat: pageFormat,
            college: college,
            version: version,
            subject: sub,
            days: days,
            allSlots: allOrderedSlots,
            entries: courseEntries,
            staffMap: staffMap,
            sectionMap: sectionMap,
            roomMap: roomMap,
          ),
        );
      }
    } else if (targetView == 'room') {
      final targetRooms = selectedRoomId != null
          ? [?roomMap[selectedRoomId]]
          : roomMap.values.toList();
      for (final r in targetRooms) {
        final roomEntries = entries.where((e) => e.roomId == r.id).toList();
        pdf.addPage(
          _buildTimetablePage(
            theme: theme,
            pageFormat: pageFormat,
            college: college,
            version: version,
            title: 'Room: ${r.roomNumber}',
            subtitle: 'Type: ${r.roomType} | Capacity: ${r.capacity} seats | Facilities: ${r.facilities.isEmpty ? "Standard" : r.facilities.join(", ")}',
            days: days,
            allSlots: allOrderedSlots,
            academicSlots: academicSlots,
            entries: roomEntries,
            staffMap: staffMap,
            sectionMap: sectionMap,
            roomMap: roomMap,
            subjectMap: subjectMap,
            viewMode: 'room',
          ),
        );
      }
    } else {
      // Consolidated
      pdf.addPage(
        _buildTimetablePage(
          theme: theme,
          pageFormat: pageFormat,
          college: college,
          version: version,
          title: 'Master Timetable Schedule',
          subtitle: 'Version: ${version?.name ?? "Draft"} | Total Scheduled Sessions: ${entries.length}',
          days: days,
          allSlots: allOrderedSlots,
          academicSlots: academicSlots,
          entries: entries,
          staffMap: staffMap,
          sectionMap: sectionMap,
          roomMap: roomMap,
          subjectMap: subjectMap,
          viewMode: 'master',
        ),
      );
    }

    return pdf.save();
  }

  static pw.Page _buildTimetablePage({
    required pw.ThemeData theme,
    required PdfPageFormat pageFormat,
    required College? college,
    required TimetableVersion? version,
    required String title,
    required String subtitle,
    required List<String> days,
    required List<TimeSlot> allSlots,
    required List<TimeSlot> academicSlots,
    required List<TimetableEntry> entries,
    required Map<String, Staff> staffMap,
    required Map<String, Section> sectionMap,
    required Map<String, Room> roomMap,
    required Map<String, Subject> subjectMap,
    required String viewMode,
    Section? targetSection,
  }) {
    return pw.MultiPage(
      pageFormat: pageFormat.landscape,
      theme: theme,
      margin: const pw.EdgeInsets.all(24),
      header: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      college?.name ?? 'COLLEGE TIMETABLE',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      title,
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      subtitle,
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColors.green300),
                  ),
                  child: pw.Text(
                    'OFFICIAL TIMETABLE',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
          ],
        );
      },
      footer: (pw.Context context) {
        return pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Version: ${version?.name ?? version?.id ?? "Draft"} | Generated Locally | Safe & Read-Only',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        );
      },
      build: (pw.Context context) {
        final infoItems = extractCourseFacultyVenueInfo(
          entries: entries,
          subjects: subjectMap.values.toList(),
          staffMap: staffMap,
          roomMap: roomMap,
          targetSection: targetSection,
          viewMode: viewMode,
        );

        return [
          _buildMatrixTable(
            days: days,
            slots: academicSlots,
            entries: entries,
            staffMap: staffMap,
            sectionMap: sectionMap,
            roomMap: roomMap,
            subjectMap: subjectMap,
            viewMode: viewMode,
          ),
          if (infoItems.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.NewPage(freeSpace: 50),
            ..._buildCourseFacultyVenueWidgets(
              items: infoItems,
              targetSection: targetSection,
            ),
          ],
        ];
      },
    );
  }

  static List<pw.Widget> _buildCourseFacultyVenueWidgets({
    required List<CourseFacultyVenueInfo> items,
    required Section? targetSection,
  }) {
    return [
      // Title Bar
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: const pw.BoxDecoration(
          color: PdfColors.grey200,
          border: pw.Border(
            top: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
            left: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
            right: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
            bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
          ),
        ),
        child: pw.Row(
          children: [
            pw.Text(
              'Course / Faculty / Venue Information',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColors.blueGrey900,
              ),
            ),
            if (targetSection != null) ...[
              pw.SizedBox(width: 6),
              pw.Text(
                '- ${targetSection.displayName}',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.blueGrey700,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
      // Information Table
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        columnWidths: const {
          0: pw.FixedColumnWidth(85), // Course Code
          1: pw.FixedColumnWidth(95), // Course Short Name
          2: pw.FlexColumnWidth(2.6), // Course Name
          3: pw.FlexColumnWidth(1.8), // Faculty
          4: pw.FlexColumnWidth(1.8), // Venue
        },
        children: [
          // Header Row
          pw.TableRow(
            repeat: true,
            decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            children: [
              _buildInfoTableHeaderCell('Course Code'),
              _buildInfoTableHeaderCell('Course Short Name'),
              _buildInfoTableHeaderCell('Course Name'),
              _buildInfoTableHeaderCell('Faculty'),
              _buildInfoTableHeaderCell('Venue'),
            ],
          ),
          // Data Rows
          ...items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final isEven = idx % 2 == 0;
            final rowColor = isEven ? PdfColors.white : PdfColors.grey50;

            return pw.TableRow(
              decoration: pw.BoxDecoration(color: rowColor),
              children: [
                _buildInfoTableCell(item.courseCode, isBold: true),
                _buildInfoTableCell(
                  item.courseShortName,
                  isBold: true,
                  textColor: PdfColors.blue800,
                ),
                _buildInfoTableCell(item.courseName),
                _buildInfoTableCell(item.faculty),
                _buildInfoTableCell(item.venue),
              ],
            );
          }),
        ],
      ),
    ];
  }

  static pw.Widget _buildInfoTableHeaderCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      alignment: pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _buildInfoTableCell(
    String text, {
    bool isBold = false,
    PdfColor textColor = PdfColors.blueGrey900,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4.5),
      alignment: pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        softWrap: true,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor,
        ),
      ),
    );
  }

  static pw.Widget _buildMatrixTable({
    required List<String> days,
    required List<TimeSlot> slots,
    required List<TimetableEntry> entries,
    required Map<String, Staff> staffMap,
    required Map<String, Section> sectionMap,
    required Map<String, Room> roomMap,
    required Map<String, Subject> subjectMap,
    required String viewMode,
  }) {
    // Organize entries by day and period: "Day_Period" -> List<TimetableEntry>
    final entrySlotMap = <String, List<TimetableEntry>>{};
    for (final e in entries) {
      final key = '${e.dayOfWeek}_${e.periodNumber}';
      entrySlotMap.putIfAbsent(key, () => []).add(e);
    }

    final headers = <pw.Widget>[
      pw.Container(
        padding: const pw.EdgeInsets.all(4),
        alignment: pw.Alignment.center,
        child: pw.Text(
          'Day / Period',
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        ),
      ),
      for (final slot in slots)
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          alignment: pw.Alignment.center,
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                'P${slot.periodNumber}',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              ),
              if (slot.startTime.isNotEmpty && slot.endTime.isNotEmpty)
                pw.Text(
                  '${slot.startTime}-${slot.endTime}',
                  style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey300),
                ),
            ],
          ),
        ),
    ];

    final rows = <pw.TableRow>[
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
        children: headers,
      ),
    ];

    for (final day in days) {
      final rowWidgets = <pw.Widget>[
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          alignment: pw.Alignment.centerLeft,
          color: PdfColors.grey100,
          child: pw.Text(
            day,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
          ),
        ),
      ];

      for (final slot in slots) {
        final key = '${day}_${slot.periodNumber}';
        final cellEntries = entrySlotMap[key] ?? const [];

        if (cellEntries.isEmpty) {
          rowWidgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(3),
              alignment: pw.Alignment.center,
              child: pw.Text(
                'FREE',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey400),
              ),
            ),
          );
        } else {
          final hasBatchEntries = viewMode == 'section' && cellEntries.any((e) => e.batch != null);
          final scheduledBatches = <String>{};
          if (hasBatchEntries) {
            for (final e in cellEntries) {
              if (e.batch != null) scheduledBatches.add(e.batch!);
            }
          }
          final sec = cellEntries.isNotEmpty ? sectionMap[cellEntries.first.sectionId] : null;
          final secBatches = (sec != null && sec.batches.isNotEmpty) ? sec.batches : const <String>[];

          rowWidgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(3),
              alignment: pw.Alignment.centerLeft,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  ...cellEntries.map((e) {
                    final sub = subjectMap[e.subjectId];
                    final teacher = staffMap[e.teacherId];
                    final room = roomMap[e.roomId];
                    final sec = sectionMap[e.sectionId];

                    final subName = sub?.subjectName ?? e.subjectId;
                    final isLab = sub?.isLab == true || e.batch != null;

                    String secondaryInfo;
                    if (viewMode == 'section') {
                      final profName = teacher != null ? teacher.name.split(' ').first : '';
                      final roomNum = room?.roomNumber ?? '';
                      secondaryInfo = '$profName [$roomNum]';
                    } else if (viewMode == 'teacher') {
                      final secName = sec?.displayName ?? e.sectionId;
                      final roomNum = room?.roomNumber ?? '';
                      secondaryInfo = '$secName [$roomNum]';
                    } else if (viewMode == 'room') {
                      final secName = sec?.displayName ?? e.sectionId;
                      final profName = teacher != null ? teacher.name.split(' ').first : '';
                      secondaryInfo = '$secName - $profName';
                    } else {
                      final secName = sec?.displayName ?? '';
                      final roomNum = room?.roomNumber ?? '';
                      secondaryInfo = '$secName [$roomNum]';
                    }

                    return pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 2),
                      padding: const pw.EdgeInsets.all(2),
                      decoration: pw.BoxDecoration(
                        color: isLab ? PdfColors.indigo50 : PdfColors.blue50,
                        borderRadius: pw.BorderRadius.circular(2),
                        border: pw.Border.all(
                          color: isLab ? PdfColors.indigo200 : PdfColors.blue200,
                          width: 0.5,
                        ),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            mainAxisSize: pw.MainAxisSize.min,
                            children: [
                              pw.Expanded(
                                child: pw.Text(
                                  subName,
                                  style: pw.TextStyle(
                                    fontSize: 7,
                                    fontWeight: pw.FontWeight.bold,
                                    color: isLab ? PdfColors.indigo900 : PdfColors.blue900,
                                  ),
                                  maxLines: 1,
                                  overflow: pw.TextOverflow.clip,
                                ),
                              ),
                              if (e.batch != null)
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                                  decoration: pw.BoxDecoration(
                                    color: PdfColors.indigo100,
                                    borderRadius: pw.BorderRadius.circular(2),
                                  ),
                                  child: pw.Text(
                                    e.batch!,
                                    style: pw.TextStyle(
                                      fontSize: 6,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.indigo800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          pw.Text(
                            secondaryInfo,
                            style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                          ),
                        ],
                      ),
                    );
                  }),
                  if (hasBatchEntries)
                    ...secBatches.where((b) => !scheduledBatches.contains(b)).map(
                          (b) => pw.Container(
                            margin: const pw.EdgeInsets.only(bottom: 2),
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.grey100,
                              borderRadius: pw.BorderRadius.circular(2),
                              border: pw.Border.all(
                                color: PdfColors.grey300,
                                width: 0.5,
                              ),
                            ),
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  'FREE',
                                  style: const pw.TextStyle(
                                    fontSize: 6,
                                    color: PdfColors.grey600,
                                  ),
                                ),
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                                  decoration: pw.BoxDecoration(
                                    color: PdfColors.grey200,
                                    borderRadius: pw.BorderRadius.circular(2),
                                  ),
                                  child: pw.Text(
                                    b,
                                    style: pw.TextStyle(
                                      fontSize: 6,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.grey700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ],
              ),
            ),
          );
        }
      }

      rows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
          ),
          children: rowWidgets,
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(65),
        for (var i = 1; i <= slots.length; i++) i: const pw.FlexColumnWidth(1),
      },
      children: rows,
    );
  }

  static pw.Page _buildCoursePage({
    required pw.ThemeData theme,
    required PdfPageFormat pageFormat,
    required College? college,
    required TimetableVersion? version,
    required Subject subject,
    required List<String> days,
    required List<TimeSlot> allSlots,
    required List<TimetableEntry> entries,
    required Map<String, Staff> staffMap,
    required Map<String, Section> sectionMap,
    required Map<String, Room> roomMap,
  }) {
    final dayIndexMap = {for (int i = 0; i < days.length; i++) days[i]: i};
    final sortedEntries = [...entries]..sort((a, b) {
        final da = dayIndexMap[a.dayOfWeek] ?? 99;
        final db = dayIndexMap[b.dayOfWeek] ?? 99;
        if (da != db) return da.compareTo(db);
        if (a.periodNumber != b.periodNumber) return a.periodNumber.compareTo(b.periodNumber);
        return (a.batch ?? '').compareTo(b.batch ?? '');
      });

    final slotMap = {for (final s in allSlots) s.periodNumber: s};

    return pw.MultiPage(
      pageFormat: pageFormat.landscape,
      theme: theme,
      margin: const pw.EdgeInsets.all(24),
      header: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      college?.name ?? 'COLLEGE TIMETABLE',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Course: ${subject.subjectName} (${subject.subjectCode})',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Type: ${subject.subjectType} | Required Hours/Wk: ${subject.hoursPerWeek} | Total Scheduled Sessions: ${entries.length}',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColors.green300),
                  ),
                  child: pw.Text(
                    'OFFICIAL COURSE SCHEDULE',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
          ],
        );
      },
      footer: (pw.Context context) {
        return pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Version: ${version?.name ?? version?.id ?? "Draft"} | Generated Locally | Safe & Read-Only',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        );
      },
      build: (pw.Context context) {
        return [
          if (sortedEntries.isEmpty)
            pw.Center(
              child: pw.Text(
                'No scheduled sessions found for this course.',
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
              ),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(80),
                1: pw.FixedColumnWidth(110),
                2: pw.FixedColumnWidth(90),
                3: pw.FixedColumnWidth(60),
                4: pw.FlexColumnWidth(2),
                5: pw.FlexColumnWidth(1.5),
                6: pw.FixedColumnWidth(70),
              },
              children: [
                // Header
                pw.TableRow(
                  repeat: true,
                  decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                  children: [
                    _courseTableHeader('Day'),
                    _courseTableHeader('Period / Time'),
                    _courseTableHeader('Section'),
                    _courseTableHeader('Batch'),
                    _courseTableHeader('Faculty'),
                    _courseTableHeader('Room'),
                    _courseTableHeader('Type'),
                  ],
                ),
                // Data rows
                ...sortedEntries.map((e) {
                  final slot = slotMap[e.periodNumber];
                  final sec = sectionMap[e.sectionId];
                  final prof = staffMap[e.teacherId];
                  final room = roomMap[e.roomId];
                  final timeStr = slot != null && slot.startTime.isNotEmpty
                      ? 'P${e.periodNumber} (${slot.startTime}-${slot.endTime})'
                      : 'Period ${e.periodNumber}';

                  return pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                      ),
                    ),
                    children: [
                      _courseTableCell(e.dayOfWeek),
                      _courseTableCell(timeStr),
                      _courseTableCell(sec?.displayName ?? e.sectionId),
                      _courseTableCell(e.batch ?? 'Whole Section', isBold: e.batch != null),
                      _courseTableCell(prof?.name ?? 'Assigned Faculty'),
                      _courseTableCell(room?.roomNumber ?? 'Unassigned'),
                      _courseTableCell(subject.subjectType),
                    ],
                  );
                }),
              ],
            ),
        ];
      },
    );
  }

  static pw.Widget _courseTableHeader(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      alignment: pw.Alignment.centerLeft,
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      ),
    );
  }

  static pw.Widget _courseTableCell(String text, {bool isBold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      alignment: pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isBold ? PdfColors.indigo900 : PdfColors.blueGrey900,
        ),
      ),
    );
  }

  /// Triggers local native printing or 'Save as PDF'.
  /// ZERO Firestore operations are performed.
  static Future<void> printTimetable({
    required College? college,
    required TimetableVersion? version,
    required List<TimetableEntry> entries,
    required List<TimeSlot> timeSlots,
    required Map<String, Staff> staffMap,
    required Map<String, Section> sectionMap,
    required Map<String, Room> roomMap,
    required Map<String, Subject> subjectMap,
    required String targetView,
    String? selectedSectionId,
    String? selectedTeacherId,
    String? selectedSubjectId,
    String? selectedRoomId,
    List<String>? workingDays,
  }) async {
    await Printing.layoutPdf(
      name: '${college?.name ?? "Timetable"}_${targetView}_Schedule.pdf',
      onLayout: (format) => generateTimetablePdf(
        pageFormat: format,
        college: college,
        version: version,
        entries: entries,
        timeSlots: timeSlots,
        staffMap: staffMap,
        sectionMap: sectionMap,
        roomMap: roomMap,
        subjectMap: subjectMap,
        targetView: targetView,
        selectedSectionId: selectedSectionId,
        selectedTeacherId: selectedTeacherId,
        selectedSubjectId: selectedSubjectId,
        selectedRoomId: selectedRoomId,
        workingDays: workingDays,
      ),
    );
  }

  /// Triggers local native sharing / download of the generated PDF file.
  /// ZERO Firestore operations are performed.
  static Future<void> shareTimetablePdf({
    required College? college,
    required TimetableVersion? version,
    required List<TimetableEntry> entries,
    required List<TimeSlot> timeSlots,
    required Map<String, Staff> staffMap,
    required Map<String, Section> sectionMap,
    required Map<String, Room> roomMap,
    required Map<String, Subject> subjectMap,
    required String targetView,
    String? selectedSectionId,
    String? selectedTeacherId,
    String? selectedSubjectId,
    String? selectedRoomId,
    List<String>? workingDays,
  }) async {
    final bytes = await generateTimetablePdf(
      pageFormat: PdfPageFormat.a4,
      college: college,
      version: version,
      entries: entries,
      timeSlots: timeSlots,
      staffMap: staffMap,
      sectionMap: sectionMap,
      roomMap: roomMap,
      subjectMap: subjectMap,
      targetView: targetView,
      selectedSectionId: selectedSectionId,
      selectedTeacherId: selectedTeacherId,
      selectedSubjectId: selectedSubjectId,
      selectedRoomId: selectedRoomId,
      workingDays: workingDays,
    );

    final filename = '${college?.name ?? "Timetable"}_${targetView}_Schedule.pdf'
        .replaceAll(' ', '_')
        .replaceAll('/', '_');

    await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}
