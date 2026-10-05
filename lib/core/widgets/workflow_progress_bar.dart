import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

enum WorkflowStep {
  schedule(0, 'College Schedule', '/schedule', Icons.calendar_today_outlined),
  professors(1, 'Professors', '/professors', Icons.people_outline),
  sectionsAndSubjects(2, 'Sections & Subjects', '/sections-subjects', Icons.menu_book_outlined),
  roomsAndLabs(3, 'Rooms & Labs', '/rooms', Icons.meeting_room_outlined),
  generate(4, 'Generate', '/workflow', Icons.auto_awesome_outlined),
  timetable(5, 'Timetable', '/timetable', Icons.calendar_view_week_outlined),
  conflicts(6, 'Conflicts', '/conflicts', Icons.rule_folder_outlined),
  export(7, 'Export', '/export', Icons.download_outlined);

  final int stepIndex;
  final String title;
  final String route;
  final IconData icon;

  const WorkflowStep(this.stepIndex, this.title, this.route, this.icon);
}

class WorkflowProgressBar extends StatelessWidget {
  final WorkflowStep currentStep;

  const WorkflowProgressBar({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const steps = WorkflowStep.values;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(steps.length, (idx) {
            final step = steps[idx];
            final isCurrent = step.stepIndex == currentStep.stepIndex;
            final isPassed = step.stepIndex < currentStep.stepIndex;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      context.go(step.route);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? AppTheme.primaryContainer
                            : (isPassed ? const Color(0xFFEFFDF5) : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isCurrent
                              ? AppTheme.primaryContainer
                              : (isPassed ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
                          width: isCurrent ? 1.5 : 1,
                        ),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryContainer.withValues(alpha: 0.2),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isPassed)
                            const Icon(Icons.check_circle, size: 15, color: Color(0xFF009668))
                          else
                            CircleAvatar(
                              radius: 8.5,
                              backgroundColor: isCurrent ? const Color(0xFF0051D5) : const Color(0xFFE2E8F0),
                              child: Text(
                                '${step.stepIndex + 1}',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent ? Colors.white : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          const SizedBox(width: 7),
                          Text(
                            step.title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isCurrent ? FontWeight.bold : (isPassed ? FontWeight.w600 : FontWeight.w500),
                              color: isCurrent
                                  ? Colors.white
                                  : (isPassed ? const Color(0xFF005236) : const Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (idx < steps.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    child: Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class WorkflowBottomBar extends StatelessWidget {
  final VoidCallback? onBack;
  final String? backLabel;
  final VoidCallback? onNext;
  final String nextLabel;
  final bool isNextEnabled;
  final bool isSaving;

  const WorkflowBottomBar({
    super.key,
    this.onBack,
    this.backLabel,
    this.onNext,
    required this.nextLabel,
    this.isNextEnabled = true,
    this.isSaving = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 750;

          final backBtn = onBack != null
              ? OutlinedButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: Text(backLabel ?? 'Previous Step'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                )
              : const SizedBox.shrink();

          final nextBtn = ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isNextEnabled ? AppTheme.primaryColor : Colors.grey.shade400,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            onPressed: isNextEnabled && !isSaving ? onNext : null,
            icon: isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.arrow_forward, size: 16),
            label: Text(
              isSaving ? 'Saving to Firestore...' : nextLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                nextBtn,
                if (onBack != null) ...[
                  const SizedBox(height: 10),
                  backBtn,
                ],
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              backBtn,
              nextBtn,
            ],
          );
        },
      ),
    );
  }
}
