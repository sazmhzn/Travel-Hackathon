import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tt/core/app_theme.dart';
import 'package:tt/features/auth/presentation/login_screen.dart';

void main() {
  testWidgets('Login screen renders the branded sign-in form',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const LoginScreen(),
        ),
      ),
    );

    expect(find.text('Travel & Emergency'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
