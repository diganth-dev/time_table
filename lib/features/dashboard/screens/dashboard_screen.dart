import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final college = ref.watch(currentCollegeProvider).value;
    final staffList = ref.watch(staffListProvider).value ?? [];
    final sections = ref.watch(sectionListProvider).value ?? [];
    final subjects = ref.watch(subjectListProvider).value ?? [];
    final rooms = ref.watch(roomListProvider).value ?? [];
    final timeSlots = ref.watch(timeSlotsProvider).value ?? [];
    final academicSlots = timeSlots.where((s) => !s.isBreak).toList();
    final conflicts = ref.watch(conflictsListProvider).value ?? [];
    final hardConflicts = conflicts.where((c) => c.isHard).length;
    final entries = ref.watch(timetableEntriesProvider).value ?? [];
    final versions = ref.watch(timetableVersionsProvider).value ?? [];
    final activeVersion = versions.where((v) => v.isPublished).firstOrNull ?? versions.firstOrNull;

    // Check readiness of 6 workflow steps
    final hasSchedule = (college?.workingDays.isNotEmpty ?? false) && academicSlots.isNotEmpty;
    final hasProfessors = staffList.isNotEmpty;
    final hasSections = sections.isNotEmpty;
    final hasSubjects = subjects.isNotEmpty;
    final hasRooms = rooms.isNotEmpty;
    final isGenerated = entries.isNotEmpty;

    final completedSteps = [
      hasSchedule,
      hasProfessors,
      hasSections,
      hasSubjects,
      hasRooms,
      isGenerated,
    ].where((c) => c).length;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Welcome Hero Card with primary "CREATE TIMETABLE" CTA
            _buildHeroCta(context, college, completedSteps, activeVersion),
            const SizedBox(height: 24),

            // No Timetable Data State Banner
            if (entries.isEmpty && staffList.isEmpty && sections.isEmpty) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 26),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No timetable data yet.',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Enter your college information to create a timetable.',
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/workflow'),
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('Start Setup (Step 1)'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Hard Conflicts Warning Banner if any
            if (hardConflicts > 0) ...[
              Card(
                color: const Color(0xFFFEF2F2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$hardConflicts Conflict(s) Detected in Current Schedule',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.errorColor, fontSize: 15),
                            ),
                            const Text(
                              'Teacher overlaps, room double-bookings, or broken constraints require attention.',
                              style: TextStyle(color: Color(0xFF7F1D1D), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                        onPressed: () => context.go('/conflicts'),
                        icon: const Icon(Icons.rule, size: 16),
                        label: const Text('Resolve Conflicts'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 6-Step Input Workflow Progress Checklist
            _buildProgressChecklist(
              context,
              hasSchedule: hasSchedule,
              hasProfessors: hasProfessors,
              hasSections: hasSections,
              hasSubjects: hasSubjects,
              hasRooms: hasRooms,
              isGenerated: isGenerated,
              college: college,
              profCount: staffList.length,
              secCount: sections.length,
              subjCount: subjects.length,
              roomCount: rooms.length,
            ),
            const SizedBox(height: 24),

            // Timetable Engine Status & Metrics
            const Text(
              'Timetable Engine Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 1000 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: constraints.maxWidth > 1200
                      ? 2.2
                      : (constraints.maxWidth > 800 ? 2.0 : 2.4),
                  children: [
                    StatCard(
                      title: 'Scheduled Classes',
                      value: '${entries.length}',
                      subtitle: 'Active periods booked',
                      icon: Icons.calendar_month,
                      iconColor: AppTheme.primaryColor,
                    ),
                    StatCard(
                      title: 'Faculty Assigned',
                      value: '${staffList.where((s) => s.status == 'active').length}',
                      subtitle: 'Professors teaching',
                      icon: Icons.badge,
                      iconColor: AppTheme.secondaryColor,
                    ),
                    StatCard(
                      title: 'Rooms / Labs Utilized',
                      value: '${rooms.where((r) => !r.isUnderMaintenance).length}',
                      subtitle: '${rooms.where((r) => r.isUnderMaintenance).length} in maintenance',
                      icon: Icons.meeting_room,
                      iconColor: const Color(0xFF8B5CF6),
                    ),
                    StatCard(
                      title: 'Constraint Conflicts',
                      value: '$hardConflicts',
                      subtitle: hardConflicts == 0 ? '✓ Zero Conflicts (Verified)' : 'Needs Resolution',
                      icon: hardConflicts == 0 ? Icons.check_circle : Icons.error,
                      iconColor: hardConflicts == 0 ? const Color(0xFF10B981) : AppTheme.errorColor,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Quick Navigation Action Cards
            const Text(
              'Quick Access & Visualizations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 800 ? 3 : (constraints.maxWidth > 500 ? 2 : 1);
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  childAspectRatio: constraints.maxWidth > 850 ? 2.6 : (constraints.maxWidth > 550 ? 2.0 : 3.5),
                  children: [
                    _buildActionTile(
                      context,
                      title: 'Section Timetable',
                      subtitle: 'View weekly matrix by class cohort',
                      icon: Icons.groups,
                      color: AppTheme.primaryColor,
                      onTap: () => context.go('/timetable'),
                    ),
                    _buildActionTile(
                      context,
                      title: 'Conflict Center',
                      subtitle: '6-point constraint verification checklist',
                      icon: Icons.rule_folder,
                      color: hardConflicts > 0 ? AppTheme.errorColor : const Color(0xFF10B981),
                      onTap: () => context.go('/conflicts'),
                    ),
                    _buildActionTile(
                      context,
                      title: 'Export Timetable',
                      subtitle: 'Download Print, CSV, PDF & JSON formats',
                      icon: Icons.download_for_offline,
                      color: const Color(0xFFF59E0B),
                      onTap: () => context.go('/export'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCta(
    BuildContext context,
    College? college,
    int completedSteps,
    TimetableVersion? activeVersion,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(24.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 700;

            final infoSection = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'AUTOMATIC TIMETABLE GENERATOR',
                    style: TextStyle(
                      color: AppTheme.secondaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  college?.name ?? 'College Timetable Generator',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Constraint satisfaction engine with backtracking optimization. Enforces professor availability, lab room requirements, break collision prevention, and balanced period distribution.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          activeVersion != null ? Icons.verified : Icons.pending_actions,
                          color: activeVersion != null ? const Color(0xFF10B981) : Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: isNarrow ? constraints.maxWidth - 60 : 350),
                          child: Text(
                            activeVersion != null
                                ? 'Active: ${activeVersion.name} (${activeVersion.status.toUpperCase()})'
                                : 'No timetable data yet. Enter your college information to create a timetable.',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Readiness: $completedSteps/6 steps',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            );

            final actionSection = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                  onPressed: () => context.go('/workflow'),
                  icon: const Icon(Icons.auto_awesome, size: 20),
                  label: const Text(
                    'CREATE TIMETABLE',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => context.go('/timetable'),
                  icon: const Icon(Icons.grid_view, size: 16, color: Colors.white70),
                  label: const Text('View Current Timetable', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ],
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  infoSection,
                  const SizedBox(height: 20),
                  actionSection,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: infoSection),
                const SizedBox(width: 24),
                actionSection,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgressChecklist(
    BuildContext context, {
    required bool hasSchedule,
    required bool hasProfessors,
    required bool hasSections,
    required bool hasSubjects,
    required bool hasRooms,
    required bool isGenerated,
    required College? college,
    required int profCount,
    required int secCount,
    required int subjCount,
    required int roomCount,
  }) {
    final steps = [
      _ChecklistItem(
        stepNumber: 1,
        title: 'College Schedule',
        subtitle: '${college?.workingDays.length ?? 0} days, timings & breaks',
        isComplete: hasSchedule,
        route: '/schedule',
      ),
      _ChecklistItem(
        stepNumber: 2,
        title: 'Professors',
        subtitle: '$profCount professors, availability & subjects',
        isComplete: hasProfessors,
        route: '/professors',
      ),
      _ChecklistItem(
        stepNumber: 3,
        title: 'Sections',
        subtitle: '$secCount sections (A, B, C)',
        isComplete: hasSections,
        route: '/sections-subjects',
      ),
      _ChecklistItem(
        stepNumber: 4,
        title: 'Subjects & Hours',
        subtitle: '$subjCount subjects (Theory / Lab)',
        isComplete: hasSubjects,
        route: '/sections-subjects',
      ),
      _ChecklistItem(
        stepNumber: 5,
        title: 'Rooms & Labs',
        subtitle: '$roomCount rooms, computer labs & capacity',
        isComplete: hasRooms,
        route: '/rooms',
      ),
      _ChecklistItem(
        stepNumber: 6,
        title: 'Generate Timetable',
        subtitle: isGenerated ? 'Schedule generated & verified' : 'Ready to generate',
        isComplete: isGenerated,
        route: '/workflow',
      ),
    ];

    return Card(
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Input Workflow Checklist',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Configure all 6 steps before running automatic generation',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.go('/workflow'),
                  icon: const Icon(Icons.play_circle_outline, size: 18),
                  label: const Text('Open Guided Wizard'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: steps.map((s) => _buildChecklistCard(context, s)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistCard(BuildContext context, _ChecklistItem item) {
    return InkWell(
      onTap: () => context.go(item.route),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 175,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: item.isComplete ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: item.isComplete ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: item.isComplete ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'STEP ${item.stepNumber}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(
                  item.isComplete ? Icons.check_circle : Icons.circle_outlined,
                  size: 18,
                  color: item.isComplete ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            Text(
              item.subtitle,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecklistItem {
  final int stepNumber;
  final String title;
  final String subtitle;
  final bool isComplete;
  final String route;

  _ChecklistItem({
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.isComplete,
    required this.route,
  });
}
