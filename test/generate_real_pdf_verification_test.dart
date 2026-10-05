import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/services/pdf_export_service.dart';

void main() {
  test('Generate PDF from actual real timetable dataset and verify Course / Faculty / Venue Information', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dumpFile = File('C:/Users/deeek/.gemini/antigravity-cli/brain/4f176d6f-4e29-4fcf-a421-4637fd04c336/scratch/firestore_dump.json');
    expect(dumpFile.existsSync(), isTrue, reason: 'Real dataset dump must exist');

    final jsonMap = jsonDecode(dumpFile.readAsStringSync()) as Map<String, dynamic>;

    final colleges = (jsonMap['colleges'] as List)
        .map((c) => College.fromJson(c as Map<String, dynamic>, id: c['id'] ?? c['_id']))
        .toList();
    final college = colleges.isNotEmpty ? colleges.first : null;

    final sections = (jsonMap['sections'] as List)
        .map((s) => Section.fromJson(s as Map<String, dynamic>, id: s['id'] ?? s['_id']))
        .toList();

    final subjects = (jsonMap['subjects'] as List)
        .map((s) => Subject.fromJson(s as Map<String, dynamic>, id: s['id'] ?? s['_id']))
        .toList();

    final staffList = (jsonMap['staff'] as List)
        .map((st) => Staff.fromJson(st as Map<String, dynamic>, id: st['id'] ?? st['_id']))
        .toList();

    final rooms = (jsonMap['rooms'] as List)
        .map((r) => Room.fromJson(r as Map<String, dynamic>, id: r['id'] ?? r['_id']))
        .toList();

    final timeSlots = (jsonMap['timeSlots'] as List)
        .map((t) => TimeSlot.fromJson(t as Map<String, dynamic>, id: t['id'] ?? t['_id']))
        .toList();

    final versions = (jsonMap['timetableVersions'] as List)
        .map((v) => TimetableVersion.fromJson(v as Map<String, dynamic>, id: v['id'] ?? v['_id']))
        .toList();

    final entries = (jsonMap['timetableEntries'] as List)
        .map((e) => TimetableEntry.fromJson(e as Map<String, dynamic>, id: e['id'] ?? e['_id']))
        .toList();

    final staffMap = {for (final st in staffList) st.id: st};
    final sectionMap = {for (final s in sections) s.id: s};
    final roomMap = {for (final r in rooms) r.id: r};
    final subjectMap = {for (final sub in subjects) sub.id: sub};

    // ignore: avoid_print
    print('Loaded real data: ${sections.length} sections, ${subjects.length} subjects, ${staffList.length} staff, ${rooms.length} rooms, ${entries.length} entries');

    // Pick the primary section with entries or the AIML section
    final targetSection = sections.firstWhere(
      (s) => entries.any((e) => e.sectionId == s.id),
      orElse: () => sections.first,
    );

    final targetVersion = versions.isNotEmpty ? versions.first : null;

    // ignore: avoid_print
    print('Target real section: ${targetSection.displayName} (id: ${targetSection.id}, batches: ${targetSection.batches})');

    // 1. Generate uncompressed PDF to verify text contents
    final uncompressedBytes = await PdfExportService.generateTimetablePdf(
      pageFormat: PdfPageFormat.a4,
      college: college,
      version: targetVersion,
      entries: entries,
      timeSlots: timeSlots,
      staffMap: staffMap,
      sectionMap: sectionMap,
      roomMap: roomMap,
      subjectMap: subjectMap,
      targetView: 'section',
      selectedSectionId: targetSection.id,
      compress: false,
    );

    final raw = latin1.decode(uncompressedBytes);
    final regex = RegExp(r'\(([^)]*)\)');
    final extractedTokens = regex.allMatches(raw).map((m) => m.group(1)!).join(' ');

    // ignore: avoid_print
    print('Checking text presence in generated PDF...');
    expect(extractedTokens.contains('Course / Faculty / Venue Information') ||
           (extractedTokens.contains('Course') && extractedTokens.contains('Faculty') && extractedTokens.contains('Venue') && extractedTokens.contains('Information')), isTrue);
    expect(extractedTokens.contains('Course Code'), isTrue);
    expect(extractedTokens.contains('Course Short Name'), isTrue);
    expect(extractedTokens.contains('Course Name'), isTrue);
    expect(extractedTokens.contains('Faculty'), isTrue);
    expect(extractedTokens.contains('Venue'), isTrue);

    // 2. Generate production compressed PDF
    final compressedBytes = await PdfExportService.generateTimetablePdf(
      pageFormat: PdfPageFormat.a4,
      college: college,
      version: targetVersion,
      entries: entries,
      timeSlots: timeSlots,
      staffMap: staffMap,
      sectionMap: sectionMap,
      roomMap: roomMap,
      subjectMap: subjectMap,
      targetView: 'section',
      selectedSectionId: targetSection.id,
      compress: true,
    );

    // Save actual PDF to scratch directory for verification
    final outputPdfFile = File('C:/Users/deeek/.gemini/antigravity-cli/brain/d0ab6b31-45b4-4c5b-bc3a-5abdaa58fc6e/scratch/real_timetable_export.pdf');
    outputPdfFile.parent.createSync(recursive: true);
    outputPdfFile.writeAsBytesSync(compressedBytes);
    // ignore: avoid_print
    print('Saved real PDF to: ${outputPdfFile.path} (${compressedBytes.length} bytes)');

    expect(outputPdfFile.existsSync(), isTrue);
    expect(compressedBytes.length, greaterThan(1000));
  });
}
