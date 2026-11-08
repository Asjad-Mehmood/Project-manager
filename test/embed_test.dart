// Project Folder Manager inside another program (the Survey Toolkit): the whole screen as one
// widget under someone else's MaterialApp and theme, in its own colours, with no update item.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_folder_manager/project_folder_manager.dart';

import 'fakes.dart';

void main() {
  testWidgets('FolderManagerView in another program\'s window: the project, its own theme, no update item', (
    tester,
  ) async {
    final h = Harness.make(settingsJson: '{"v6Checked": true, "options": {"autoIndex": false}}');
    addTearDown(h.dispose);
    h.model.start();
    h.model.setRoot(h.root.path);
    h.model.setTitle('North Gas Field');
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // the host: a light app with a sidebar, like the Toolkit
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange)),
        home: Scaffold(
          body: Row(
            children: [
              const SizedBox(width: 92, child: Text('Toolkit sidebar')),
              Expanded(child: FolderManagerView(model: h.model)),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('North Gas Field'), findsWidgets);
    expect(find.text('Toolkit sidebar'), findsOneWidget);

    // its own colours, not the host's
    final inside = Theme.of(tester.element(find.text('North Gas Field').first));
    expect(inside.brightness, Brightness.dark);

    // the More menu has no "Look for an update": the Toolkit brings new versions
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Keyboard shortcuts'), findsOneWidget);
    expect(find.text('Look for an update'), findsNothing);
  });

  test('its version is its own, not the program it runs in', () {
    expect(appName, 'Project Folder Manager');
    expect(appVersion, '7.0.0');
  });
}
