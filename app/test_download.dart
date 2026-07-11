import 'dart:io';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';

void main() async {
  print('Starting test...');
  final dio = Dio();
  final apkUrl = 'https://github.com/manil-max/online-study-room/releases/download/beta-v1/app-beta-release.apk';
  final sha256Url = 'https://github.com/manil-max/online-study-room/releases/download/beta-v1/app-beta-release.apk.sha256';
  
  try {
    print('Fetching expected sha256...');
    final res = await dio.get<String>(sha256Url);
    final expectedStr = res.data!;
    print('Expected string: \$expectedStr');
    final expected = RegExp(r'\b([a-fA-F0-9]{64})\b').firstMatch(expectedStr)?.group(1)?.toLowerCase();
    print('Expected hash: \$expected');

    print('Downloading APK...');
    final savePath = 'test.apk';
    await dio.download(apkUrl, savePath);
    print('Downloaded.');

    final bytes = await File(savePath).readAsBytes();
    final actual = sha256.convert(bytes).toString();
    print('Actual hash:   \$actual');

    if (expected == actual) {
      print('HASH MATCHES!');
    } else {
      print('HASH MISMATCH!');
    }
  } catch (e) {
    print('Error: \$e');
  }
  print('Done.');
}
