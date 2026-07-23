import 'flutter_test_host_stub.dart'
    if (dart.library.io) 'flutter_test_host_io.dart'
    as platform;

bool get isFlutterTestHost => platform.isFlutterTestHost;
