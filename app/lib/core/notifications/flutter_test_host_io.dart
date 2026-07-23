import 'dart:io';

bool get isFlutterTestHost => Platform.environment.containsKey('FLUTTER_TEST');
