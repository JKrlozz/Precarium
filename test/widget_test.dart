import 'package:flutter_test/flutter_test.dart';
import 'package:precarium/app.dart';
import 'package:precarium/providers/settings_provider.dart';

void main() {
  testWidgets('App loads and shows bottom navigation', (WidgetTester tester) async {
    final settings = SettingsProvider();
    await tester.pumpWidget(PrecariumApp(settingsProvider: settings));

    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.text('Buscar'), findsOneWidget);
    expect(find.text('Descargas'), findsOneWidget);
  });
}
