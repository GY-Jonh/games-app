import 'dart:io';
import 'package:uuid/uuid.dart';

String _deviceId = '';
String _customDeviceName = '';
String? _systemHostname;

String get deviceId {
  if (_deviceId.isEmpty) {
    _deviceId = const Uuid().v4();
  }
  return _deviceId;
}

String get deviceName {
  if (_customDeviceName.isNotEmpty) return _customDeviceName;
  _systemHostname ??= _resolveHostname();
  return _systemHostname!;
}

String _resolveHostname() {
  try {
    return Platform.localHostname;
  } catch (_) {
    return 'Unknown Device';
  }
}

void setCustomDeviceName(String name) {
  _customDeviceName = name;
}

String get platform {
  if (Platform.isIOS) return 'ios';
  if (Platform.isAndroid) return 'android';
  if (Platform.isMacOS) return 'macos';
  return 'unknown';
}
