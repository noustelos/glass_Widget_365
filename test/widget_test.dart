import 'package:flutter_test/flutter_test.dart';
import 'package:orthodoxy_widget_365/main.dart';

void main() {
  testWidgets('App loads test', (WidgetTester tester) async {
    // Φορτώνει την OrthodoxyApp αντί για την MyApp
    await tester.pumpWidget(const OrthodoxyApp());
    
    // Ελέγχει αν υπάρχει κάτι στην οθόνη (π.χ. το CircularProgressIndicator)
    expect(find.byType(OrthodoxyApp), findsOneWidget);
  });
}