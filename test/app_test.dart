import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ink_notes/main.dart';

void main() {
  testWidgets('InkNotesApp startup smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('es_ES', null);

    await tester.pumpWidget(const InkNotesApp());
    await tester.pumpAndSettle();

    expect(find.text('inkNotes'), findsOneWidget);
  });
}
