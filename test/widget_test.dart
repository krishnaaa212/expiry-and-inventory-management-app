import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expiry_and_inventory/main.dart'; // Imports the main app

void main() {
  testWidgets('Login page loads correctly', (WidgetTester tester) async {
    // Build the app and trigger a frame
    await tester.pumpWidget(MyApp());

    // Verify the app title is displayed on the login page
    expect(
      find.text('Expiry and Inventory Management App'),
      findsOneWidget,
    );

    // Verify the Email input field is present
    expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);

    // Verify the Password input field is present
    expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);

    // Verify the Login button is present
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);

    // Verify the Create New Account button is present
    expect(find.widgetWithText(TextButton, 'Create New Account'), findsOneWidget);

    // Verify the Forgot Password button is present
    expect(find.widgetWithText(TextButton, 'Forgot Password?'), findsOneWidget);
  });
}