import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared test setup: loads the app's real Arabic font so widget and
/// golden tests render text with IBMPlexSansArabic instead of the test
/// environment's placeholder font. Without this, golden images would
/// lock in the wrong typography.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fontLoader = FontLoader('IBMPlexSansArabic')
    ..addFont(rootBundle.load('assets/fonts/IBMPlexSansArabic-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/IBMPlexSansArabic-Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/IBMPlexSansArabic-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/IBMPlexSansArabic-Bold.ttf'));
  await fontLoader.load();
  await testMain();
}
