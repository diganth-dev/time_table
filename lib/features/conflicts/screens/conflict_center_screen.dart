import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/workflow_progress_bar.dart';
import '../../../providers/providers.dart';

class ConflictCenterScreen extends ConsumerStatefulWidget {
  const ConflictCenterScreen({super.key});

  @override
  ConsumerState<ConflictCenterScreen> createState() => _ConflictCenterScreenState();
}

class _ConflictCenterScreenState extends ConsumerState<ConflictCenterScreen> {
  String _severityFilter = 'all'; // all, hard, warning
  bool _isRegenerating = false;

  Future<void> _handleRegenerate() async {
    setState(() => _isRegenerating = true);
    try {
      final result = await ref.read(timetableControllerProvider.notifier).generateSchedule();
      ref.invalidate(timetableVersionsProvider);
      ref.invalidate(timetableEntriesProvider);
      ref.invalidate(conflictsListProvider);

      if (mounted) {
        if (result.isSuccess && result.conflicts.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF16A34A),
              content: Text(
                'Timetable generated successfully! ${result.totalClassesScheduled} classes scheduled with 0 hard conflicts.',
              ),
              action: SnackBarAction(
                label: 'View Matrix',
                textColor: Colors.white,
                onPressed: () => context.go('/timetable'),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.errorColor,
              content: Text(
                'Generation completed with ${result.conflicts.length} conflict(s): ${result.summaryMessage}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.errorColor,
            content: Text('Generation failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRegenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final conflictsAsync = ref.watch(conflictsListProvider);
    final conflicts = conflictsAsync.value ?? [];
    final staffList = ref.watch(staffListProvider).value ?? [];
    final sections = ref.watch(sectionListProvider).value ?? [];
    final rooms = ref.watch(roomListProvider).value ?? [];
    final subjects = ref.watch(subjectListProvider).value ?? [];
    final entries = ref.watch(timetableEntriesProvider).value ?? [];

    final staffMap = {for (var s in staffList) s.id: s};
    final sectionMap = {for (var s in sections) s.id: s};
    final roomMap = {for (var r in rooms) r.id: r};
    final subjectMap = {for (var s in subjects) s.id: s};

    // Calculate the 6 Verification Checklist Criteria
    final profConflicts = conflicts.where((c) => c.type == 'teacherConflict').length;
    final secConflicts = conflicts.where((c) => c.type == 'sectionConflict').length;
    final roomConflicts = conflicts.where((c) => c.type == 'roomConflict').length;
    final weeklySubjectConflicts = conflicts.where((c) => c.type == 'incompleteHours').length;
    final labConflicts = conflicts.where((c) =>
        c.type == 'insufficientLabs' ||
        c.type == 'labBatchMissing' ||
        c.type == 'labCompanionMissing' ||
        c.type == 'labSameRoomConflict').length;
    final availabilityConflicts = conflicts.where((c) =>
        c.type == 'availabilityConflict' ||
        c.type == 'teacherLeaveConflict' ||
        c.type == 'teacherUnavailabilityConflict' ||
        c.type == 'breakCollisionConflict' ||
        c.type == 'maxClassesPerDayExceeded').length;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WorkflowProgressBar(currentStep: WorkflowStep.conflicts),
            const SizedBox(height: 20),

            // Top Bar
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 800;
                final titleColumn = const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conflict Center & Constraint Verification',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Verification checklist and diagnosis of professor overlaps, section clashes, room availability, and hours',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                );

                final buttons = Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isRegenerating
                          ? null
                          : () async {
                              final currentVerId = ref.read(selectedVersionIdProvider);
                              await ref.read(conflictControllerProvider.notifier).recomputeConflicts(versionId: currentVerId);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Constraint validation rerun across active timetable version.')),
                                );
                              }
                            },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Re-evaluate Schedule'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isRegenerating ? null : _handleRegenerate,
                      icon: _isRegenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: Text(_isRegenerating ? 'Generating Schedule...' : 'Re-generate Timetable'),
                    ),
                  ],
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleColumn,
                      const SizedBox(height: 12),
                      buttons,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    titleColumn,
                    buttons,
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            if (entries.isEmpty)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 56, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 16),
                        const Text(
                          'No timetable data yet.',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Enter your college information to create a timetable.',
                          style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => context.go('/workflow'),
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          label: const Text('Start Input Workflow'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              // 6-Point Verification Checklist Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Verification Checklist (6 Rules)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: conflicts.isEmpty ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            conflicts.isEmpty ? 'ALL CONSTRAINTS SATISFIED' : '${conflicts.length} ISSUES DETECTED',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: conflicts.isEmpty ? const Color(0xFF15803D) : const Color(0xFF991B1B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final cols = width >= 900 ? 3 : (width >= 600 ? 2 : 1);
                        return GridView.count(
                          crossAxisCount: cols,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: cols == 3 ? 2.6 : (cols == 2 ? 3.0 : 4.2),
                          children: [
                            _checklistTile(
                              title: 'Professor Conflicts',
                              statusText: profConflicts == 0 ? '0 conflicts' : '$profConflicts conflict(s)',
                              isSatisfied: profConflicts == 0,
                              icon: Icons.person_off_outlined,
                            ),
                            _checklistTile(
                              title: 'Section Conflicts',
                              statusText: secConflicts == 0 ? '0 conflicts' : '$secConflicts conflict(s)',
                              isSatisfied: secConflicts == 0,
                              icon: Icons.group_off_outlined,
                            ),
                            _checklistTile(
                              title: 'Room Conflicts',
                              statusText: roomConflicts == 0 ? '0 conflicts' : '$roomConflicts conflict(s)',
                              isSatisfied: roomConflicts == 0,
                              icon: Icons.meeting_room_outlined,
                            ),
                            _checklistTile(
                              title: 'Weekly Subject Requirements',
                              statusText: weeklySubjectConflicts == 0 ? 'satisfied' : '$weeklySubjectConflicts pending',
                              isSatisfied: weeklySubjectConflicts == 0,
                              icon: Icons.menu_book_outlined,
                            ),
                            _checklistTile(
                              title: 'Lab Requirements',
                              statusText: labConflicts == 0 ? 'satisfied' : '$labConflicts pending',
                              isSatisfied: labConflicts == 0,
                              icon: Icons.biotech_outlined,
                            ),
                            _checklistTile(
                              title: 'Availability Constraints',
                              statusText: availabilityConflicts == 0 ? 'satisfied' : '$availabilityConflicts violated',
                              isSatisfied: availabilityConflicts == 0,
                              icon: Icons.event_available_outlined,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Filter Bar
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list, size: 18, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    const Text('Filter By Severity:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _severityFilter,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Severities')),
                        DropdownMenuItem(value: 'hard', child: Text('Hard Conflicts (Blocking)')),
                        DropdownMenuItem(value: 'warning', child: Text('Warnings (Optimization)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _severityFilter = val);
                      },
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Clear All Conflicts'),
                      onPressed: () => ref.read(conflictControllerProvider.notifier).clearAllConflicts(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Conflicts Diagnostic List
            conflictsAsync.when(
              data: (conflictsList) {
                var filtered = conflictsList;
                if (_severityFilter != 'all') {
                  filtered = filtered.where((c) => c.severity == _severityFilter).toList();
                }

                if (filtered.isEmpty) {
                  return const Card(
                    elevation: 0,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 60.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.verified, size: 54, color: Color(0xFF16A34A)),
                            SizedBox(height: 16),
                            Text(
                              'Timetable satisfies all 6 validation criteria!',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Zero professor overlaps, zero section clashes, zero room double-bookings, and all weekly requirements met.',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final item = filtered[idx];
                    final isHard = item.isHard;

                    // Resolve affected entities
                    final profName = item.teacherId != null ? staffMap[item.teacherId]?.name : null;
                    final secName = item.sectionId != null ? sectionMap[item.sectionId]?.displayName : null;
                    final roomName = item.roomId != null ? roomMap[item.roomId]?.roomNumber : null;
                    final subjName = item.subjectId != null ? subjectMap[item.subjectId]?.subjectName : null;

                    return Card(
                      color: isHard ? const Color(0xFFFFF1F2) : const Color(0xFFFFFBEB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: isHard ? const Color(0xFFFECDD3) : const Color(0xFFFDE68A)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isHard ? AppTheme.errorColor : Colors.amber.shade700,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isHard ? Icons.report_problem : Icons.warning_amber,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isHard ? Colors.red.shade100 : Colors.amber.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isHard ? 'HARD CONFLICT' : 'WARNING',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isHard ? Colors.red.shade900 : Colors.amber.shade900,
                                          ),
                                        ),
                                      ),
                                      if (item.dayOfWeek != null) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          '${item.dayOfWeek} • Period ${item.periodNumber ?? ""}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.description,
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                                  ),

                                  // Affected entities breakdown
                                  if (profName != null || secName != null || roomName != null || subjName != null) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        if (profName != null) _entityChip('Professor', profName, Icons.person),
                                        if (secName != null) _entityChip('Section', secName, Icons.group),
                                        if (roomName != null) _entityChip('Room', roomName, Icons.meeting_room),
                                        if (subjName != null) _entityChip('Subject', subjName, Icons.menu_book),
                                      ],
                                    ),
                                  ],

                                  // Actionable Suggestion to fix
                                  if (item.suggestion != null) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFFD97706)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Actionable Fix: ${item.suggestion!}',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
              error: (e, _) => Center(child: Text('Error loading conflicts: $e')),
            ),
            ],

            // Step Navigation Controls
            WorkflowBottomBar(
              backLabel: '← Back to Timetable',
              onBack: () => context.go('/timetable'),
              nextLabel: 'Proceed to Export & Print →',
              onNext: () => context.go('/export'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checklistTile({
    required String title,
    required String statusText,
    required bool isSatisfied,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSatisfied ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSatisfied ? const Color(0xFFBBF7D0) : const Color(0xFFFECDD3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSatisfied ? Icons.check_circle : Icons.cancel,
            color: isSatisfied ? const Color(0xFF16A34A) : AppTheme.errorColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSatisfied ? const Color(0xFF15803D) : const Color(0xFF991B1B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _entityChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text('$label: ', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}
