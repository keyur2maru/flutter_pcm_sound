// ignore_for_file: avoid_print

import 'package:flutter/services.dart';
import 'package:flutter_pcm_sound_fork/flutter_pcm_sound_platform_interface.dart';
import 'package:flutter_pcm_sound_fork/pcm_array_int16.dart';

class MethodChannelFlutterPcmSound extends FlutterPcmSoundPlatform {
  final methodChannel = const MethodChannel('flutter_pcm_sound/methods');
  Function(int)? onFeedSamplesCallback;
  LogLevel _logLevel = LogLevel.standard;

  @override
  Future<void> setLogLevel(LogLevel level) async {
    _logLevel = level;
    return _invokeMethod('setLogLevel', {'log_level': level.index});
  }

  @override
  Future<void> resumeAudioContext() async {
    return _invokeMethod('resumeAudioContext');
  }

  @override
  Future<void> setup(
      {required int sampleRate,
      required int channelCount,
      IosAudioCategory iosAudioCategory = IosAudioCategory.playback}) async {
    return _invokeMethod('setup', {
      'sample_rate': sampleRate,
      'num_channels': channelCount,
      'ios_audio_category': iosAudioCategory.name,
    });
  }

  @override
  Future<void> feed(PcmArrayInt16 buffer) async {
    final Uint8List rawBytes = buffer.bytes.buffer
        .asUint8List(buffer.bytes.offsetInBytes, buffer.bytes.lengthInBytes);
    return _invokeMethod('feed', {'buffer': rawBytes});
  }

  @override
  Future<void> clearBuffer({bool force = false}) async {
    return _invokeMethod('clearBuffer', {'force': force});
  }

  @override
  Future<void> setFeedThreshold(int threshold) async {
    return _invokeMethod('setFeedThreshold', {'feed_threshold': threshold});
  }

  @override
  Future<void> release() async {
    return _invokeMethod('release');
  }

  @override
  void setFeedCallback(Function(int)? callback) {
    onFeedSamplesCallback = callback;
    methodChannel.setMethodCallHandler(_methodCallHandler);
  }

  Future<T?> _invokeMethod<T>(String method, [dynamic arguments]) async {
    if (_logLevel.index >= LogLevel.standard.index) {
      String args = '';
      if (method == 'feed') {
        Uint8List data = arguments['buffer'];
        if (data.lengthInBytes > 6) {
          args =
              '(${data.lengthInBytes ~/ 2} samples) ${data.sublist(0, 6)} ...';
        } else {
          args = '(${data.lengthInBytes ~/ 2} samples) $data';
        }
      } else if (arguments != null) {
        args = arguments.toString();
      }
      print("[PCM] invoke: $method $args");
    }
    return methodChannel.invokeMethod(method, arguments);
  }

  Future<dynamic> _methodCallHandler(MethodCall call) async {
    if (_logLevel.index >= LogLevel.standard.index) {
      String func = '[[ ${call.method} ]]';
      String args = call.arguments.toString();
      print("[PCM] $func $args");
    }
    switch (call.method) {
      case 'OnFeedSamples':
        int remainingFrames = call.arguments["remaining_frames"];
        if (onFeedSamplesCallback != null) {
          onFeedSamplesCallback!(remainingFrames);
        }
        break;
      default:
        print('Method not implemented');
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    // Clamp volume between 0.0 and 1.0
    final clampedVolume = volume.clamp(0.0, 1.0);
    return _invokeMethod('setVolume', {'volume': clampedVolume});
  }

  @override
  Future<double> getVolume() async {
    final result = await _invokeMethod<double>('getVolume');
    return result ?? 1.0;
  }
}
