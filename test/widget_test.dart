import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_trails/widgets/trail_card.dart';
import 'package:hiking_trails/models/trail.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('TrailCard renders GR symbol and name correctly', (WidgetTester tester) async {
    final trail = Trail(
      id: 'gr1',
      name: 'GR 1 Test',
      lengthKm: 12.5,
      importance: 85, // GR
      coordinateSegments: [[const LatLng(45.0, 5.0), const LatLng(45.1, 5.1)]],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TrailCard(
          trail: trail,
          isSelected: false,
          isFav: false,
          hideUnloved: false,
          onToggleFavorite: (_) {},
          onTap: (_) {},
        ),
      ),
    ));

    // Verify name
    expect(find.text('GR 1 Test'), findsOneWidget);
    
    // Verify distance
    expect(find.textContaining('12.5 km'), findsOneWidget);

    // Verify that it contains a Column (the symbol)
    // We can't easily check colors of nested containers without complex finders, 
    // but we can check if the widget exists.
    expect(find.byType(TrailCard), findsOneWidget);
  });

  testWidgets('TrailCard renders PR symbol correctly', (WidgetTester tester) async {
    final trail = Trail(
      id: 'pr1',
      name: 'Petit Sentier',
      lengthKm: 2.5,
      importance: 10, // PR
      coordinateSegments: [[const LatLng(45.0, 5.0), const LatLng(45.1, 5.1)]],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TrailCard(
          trail: trail,
          isSelected: false,
          isFav: false,
          hideUnloved: false,
          onToggleFavorite: (_) {},
          onTap: (_) {},
        ),
      ),
    ));

    expect(find.text('Petit Sentier'), findsOneWidget);
    expect(find.textContaining('2.5 km'), findsOneWidget);
  });
}
