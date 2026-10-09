import 'package:flutter/services.dart';

class MobileClipboardService {
  Future<String> getSystemClipboardText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text ?? '';
  }

  Future<void> setSystemClipboardText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
