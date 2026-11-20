import 'package:flutter/services.dart';

class HomeWidgetBridge {
  static const channel = MethodChannel('inknotes/widget');

  static Future<void> refresh() async {
    try {
      await channel.invokeMethod<void>('refresh');
    } on MissingPluginException {
      // Other platforms retain the in-app quick-note flow.
    } on PlatformException {
      // A launcher widget is optional.
    }
  }
}
