import 'package:flutter/services.dart';

class GenAI {
  static const MethodChannel _methodChannel =
      MethodChannel('com.example.flutter.flutter_gen_ai_demo/channel/method');
  static const EventChannel _eventChannel =
      EventChannel('com.example.flutter.flutter_gen_ai_demo/channel/event');

  // Cache the broadcast stream so we don't create a new one each time
  static Stream<String>? _tokenStreamInstance;

  static Future<String> load(String path) async {
    print('GenAI.load: Loading model from $path');
    final result = await _methodChannel.invokeMethod('load', path);
    print('GenAI.load: Result = $result');
    return result;
  }

  static Future<String> inference(String prompt,
      {Map<String, double>? params}) async {
    print('GenAI.inference: Starting with prompt length ${prompt.length}');
    final result = await _methodChannel.invokeMethod('inference', {
      'prompt': prompt,
      'params': params,
    });
    print('GenAI.inference: Result = $result');
    return result;
  }

  static Future<String> unload() async {
    return await _methodChannel.invokeMethod('unload');
  }

  static Future<String> copyModelFromUri(
      String folderUri, String targetDir, List<String> files) async {
    return await _methodChannel.invokeMethod('copyModelFromUri', {
      'folderUri': folderUri,
      'targetDir': targetDir,
      'files': files,
    });
  }

  static Stream<String> get tokenStream {
    _tokenStreamInstance ??=
        _eventChannel.receiveBroadcastStream().map((event) {
      final token = event.toString();
      print(
          'GenAI.tokenStream: Received token: "$token" (length: ${token.length})');
      return token;
    }).asBroadcastStream();
    return _tokenStreamInstance!;
  }
}
