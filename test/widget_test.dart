import 'package:flutter_test/flutter_test.dart';
import 'package:precarium/app.dart';

void main() {
  testWidgets('App loads and shows bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const PrecariumApp());

    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.text('Buscar'), findsOneWidget);
    expect(find.text('Descargas'), findsOneWidget);
  });
}
