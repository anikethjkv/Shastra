import 'package:flutter_test/flutter_test.dart';
import 'package:shastra_ev/main.dart';
import 'package:provider/provider.dart';
import 'package:shastra_ev/providers/vehicle_provider.dart';

void main() {
  testWidgets('App loads and shows disconnected screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => VehicleProvider()..init(),
        child: const ShastraApp(),
      ),
    );

    // App should show the disconnected state on launch
    expect(find.text('NO VEHICLE CONNECTED'), findsOneWidget);
    expect(find.text('CONNECT TO VEHICLE'), findsOneWidget);
  });
}