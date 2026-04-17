import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moviequestapp/widgets/star_rating.dart';

void main() {
  testWidgets('StarRating renders filled and empty stars', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StarRating(value: 3)),
      ),
    );

    expect(find.byIcon(Icons.star), findsNWidgets(3));
    expect(find.byIcon(Icons.star_border), findsNWidgets(2));
  });

  testWidgets('StarRating tap updates value via onChanged', (tester) async {
    int captured = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StarRating(
            value: 2,
            onChanged: (v) => captured = v,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.star_border).first);
    expect(captured, 3);
  });
}
