import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spelleider/main.dart';
import 'package:spelleider/models.dart';
import 'package:spelleider/store.dart';

Future<void> scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 300,
      scrollable: find.byType(Scrollable).hitTestable().first);
  // Iets verder, zodat de knop niet onder de zwevende navigatiebalk valt.
  await tester.drag(
      find.byType(Scrollable).hitTestable().first, const Offset(0, -200));
  await tester.pump();
  expect(f, findsOneWidget);
}

void main() {
  testWidgets('alle tabbladen en de stappen van een potje renderen',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    for (var i = 0; i < 6; i++) {
      store.addPlayer('Speler $i', i.isEven ? 's$i@x.nl' : null);
    }
    store.randomizeTeams();
    store.photos.add(Photo(id: 'f1', name: 'Rode fiets', path: '/nope.jpg'));
    store.photos.add(Photo(id: 'f2', name: 'Blauwe deur', path: '/nope2.jpg'));

    await tester.pumpWidget(const SpelleiderApp());
    await tester.pump();
    expect(find.text('Speler 0'), findsOneWidget);

    for (final tab in ['Teams', "Foto's", 'Scores', 'Potje']) {
      await tester.tap(find.text(tab).last);
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Nieuw potje'), findsOneWidget);

    await tester.tap(find.text('Nieuw potje'));
    await tester.pump();
    await tester.tap(find.text('Team 1').last);
    await tester.tap(find.text('Team 2').last);
    await tester.pump();
    await scrollTo(tester, find.text("Foto's trekken"));
    await tester.tap(find.text("Foto's trekken"));
    await tester.pump();
    await scrollTo(tester, find.text('Bevestigen'));

    await scrollTo(tester, find.text('Bevestigen'));
    await tester.tap(find.text('Bevestigen'));
    await tester.pump();
    await scrollTo(tester, find.text('Naar het spel'));

    store.markSent(0, true);
    store.markSent(1, true);
    store.setStage(MatchStage.play);
    await tester.pump();
    await tester.pump();
    expect(find.text('5:00'), findsOneWidget);

    store.startTimer();
    store.finishBy(0);
    await tester.pump();
    await scrollTo(tester, find.text('Uitslag opslaan'));
    await tester.tap(find.text('Uitslag opslaan'));
    await tester.pump();
    expect(store.history, hasLength(1));

    await tester.tap(find.text('Scores').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Scorebord'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
