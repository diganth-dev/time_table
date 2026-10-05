import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/models/models.dart';

void main() {
  const collegeId = 'col_test_1';

  final testProfNirmal = Staff(
    id: 'prof_nirmal',
    collegeId: collegeId,
    employeeId: 'EMP_NIRMAL',
    name: 'Mr Nirmal kumar nigam',
    email: 'nirmal.nigam@college.edu',
    departmentId: 'dept_cse',
    designation: 'Professor',
    status: 'active',
    active: true,
    subjectsCanTeach: [
      'Deep Learning & Reinforcement Learning',
      'Machine Learning-II',
      'Computer Networks',
      'Distributed Systems and Cloud Computing',
      'Database Management Systems & Big Data Analytics',
      'Operating Systems & System Programming',
    ],
  );
  Widget buildEditSubjectDialogDirect({
    required BuildContext context,
    required List<Staff> eligibleProfessors,
    required String selectedTeacherId,
    ValueChanged<String?>? onChanged,
  }) {
    final dialogWidth =
        (MediaQuery.of(context).size.width - 48).clamp(0.0, 520.0);

    return AlertDialog(
      title: const Text('Edit Subject'),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey('prof_${selectedTeacherId}_${eligibleProfessors.length}'),
                initialValue: selectedTeacherId.isNotEmpty ? selectedTeacherId : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Select Eligible Professor *',
                  helperText: '${eligibleProfessors.length} eligible professor(s) available',
                  border: const OutlineInputBorder(),
                ),
                hint: const Text('Choose a professor'),
                selectedItemBuilder: (BuildContext context) {
                  return eligibleProfessors.map<Widget>((s) {
                    return Text(
                      s.name,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    );
                  }).toList();
                },
                items: eligibleProfessors.map((s) {
                  final canTeachNote = s.subjectsCanTeach.isEmpty
                      ? 'All Subjects'
                      : s.subjectsCanTeach.join(', ');
                  final designationStr =
                      s.designation.isNotEmpty ? ' (${s.designation})' : '';
                  return DropdownMenuItem<String>(
                    value: s.id,
                    child: Text(
                      '${s.name}$designationStr — Can teach: $canTeachNote',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList(),
                onChanged: onChanged ?? (_) {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  group('Edit Subject Dialog Overflow & Responsiveness Tests', () {
    testWidgets(
      'Full Screen Flow: Edit Subject dialog opens and operates with zero overflow on desktop (1280x800)',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: ctx,
                      builder: (_) => buildEditSubjectDialogDirect(
                        context: ctx,
                        eligibleProfessors: [testProfNirmal],
                        selectedTeacherId: testProfNirmal.id,
                      ),
                    );
                  },
                  child: const Text('Open Edit Dialog'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the button to open the Edit Subject dialog
        await tester.tap(find.text('Open Edit Dialog'));
        await tester.pumpAndSettle();

        // 1. Verify the dialog opened with "Edit Subject"
        expect(find.text('Edit Subject'), findsOneWidget);

        // 2. Verify zero RenderFlex overflow occurred on dialog open
        expect(tester.takeException(), isNull);

        // 3. In the closed dropdown:
        // Professor's name is displayed
        expect(find.text('Mr Nirmal kumar nigam'), findsOneWidget);
        // "Can teach: ..." must NOT be displayed in the closed field
        expect(find.textContaining('Can teach:'), findsNothing);

        // 4. Tap to open the dropdown menu
        final dropdownFinder = find.byType(DropdownButtonFormField<String>);
        expect(dropdownFinder, findsWidgets);
        await tester.tap(dropdownFinder.last);
        await tester.pumpAndSettle();

        // 5. Verify zero overflow error occurred when opening the menu
        expect(tester.takeException(), isNull);

        // 6. When opened, the eligible-subject information is available in the menu items
        expect(find.textContaining('Can teach:'), findsWidgets);

        // 7. Select the professor in the opened dropdown
        final menuItemFinder = find.textContaining('Mr Nirmal kumar nigam').last;
        await tester.tap(menuItemFinder);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    for (final size in [
      const Size(1280, 800), // Desktop
      const Size(1024, 768), // Browser / Tablet Landscape
      const Size(800, 600),  // Tablet Portrait
      const Size(400, 800),  // Mobile
      const Size(360, 640),  // Small Mobile
    ]) {
      testWidgets(
        'Responsive Test: Dialog renders with zero overflow on viewport ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => buildEditSubjectDialogDirect(
                    context: context,
                    eligibleProfessors: [testProfNirmal],
                    selectedTeacherId: testProfNirmal.id,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Verify NO RenderFlex overflow when closed
          expect(tester.takeException(), isNull);

          // Verify closed field displays only the professor's name
          expect(find.text('Mr Nirmal kumar nigam'), findsOneWidget);
          // Verify closed field does NOT display "Can teach: ..."
          expect(find.textContaining('Can teach:'), findsNothing);

          // Open dropdown menu
          await tester.tap(find.byType(DropdownButtonFormField<String>));
          await tester.pumpAndSettle();

          // Verify NO RenderFlex overflow when open
          expect(tester.takeException(), isNull);

          // Verify eligible subject info is present in menu
          expect(find.textContaining('Can teach:'), findsWidgets);

          // Tap item to close
          await tester.tap(find.textContaining('Mr Nirmal kumar nigam').last);
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'Safely handles professor with extremely long name and long subject list',
      (tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const veryLongName =
            'Prof. Dr. Bartholomew Montgomery Alexander Montgomery-Smith The Third Distinguished Chair of Computational Neural Systems';

        final longNameProf = Staff(
          id: 'prof_long_name',
          collegeId: collegeId,
          employeeId: 'EMP_LONG',
          name: veryLongName,
          email: 'bart.montgomery@college.edu',
          departmentId: 'dept_cse',
          designation: 'Distinguished Professor',
          status: 'active',
          active: true,
          subjectsCanTeach: [
            'Deep Learning & Reinforcement Learning',
            'Machine Learning-II',
            'Computer Networks',
            'Distributed Systems and Cloud Computing',
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => buildEditSubjectDialogDirect(
                  context: context,
                  eligibleProfessors: [longNameProf],
                  selectedTeacherId: longNameProf.id,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Zero overflow with extremely long name
        expect(tester.takeException(), isNull);

        // Name is rendered (safely truncated via ellipsis)
        expect(find.text(veryLongName), findsOneWidget);
        expect(find.textContaining('Can teach:'), findsNothing);

        // Open menu
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });
}
