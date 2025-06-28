import 'package:flutter_pcm_sound_fork/pcm_array_int16.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:flutter_pcm_sound_fork/flutter_pcm_sound_method_channel.dart';

enum LogLevel {
  none,
  error,
  standard,
  verbose,
}

enum IosAudioCategory {
  soloAmbient,
  ambient,
  playback,
  playAndRecord,
}

abstract class FlutterPcmSoundPlatform extends PlatformInterface {
  FlutterPcmSoundPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterPcmSoundPlatform _instance = MethodChannelFlutterPcmSound();

  static FlutterPcmSoundPlatform get instance => _instance;

  static set instance(FlutterPcmSoundPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> setLogLevel(LogLevel level) {
    throw UnimplementedError('setLogLevel() has not been implemented.');
  }

  Future<void> setup(
      {required int sampleRate,
      required int channelCount,
      IosAudioCategory iosAudioCategory = IosAudioCategory.playback}) {
    throw UnimplementedError('setup() has not been implemented.');
  }

  Future<void> resumeAudioContext() {
    throw UnimplementedError('resumeAudioContext() has not been implemented.');
  }

  Future<void> feed(PcmArrayInt16 buffer) {
    throw UnimplementedError('feed() has not been implemented.');
  }

  Future<void> clearBuffer({bool force = false}) {
    throw UnimplementedError('clearBuffer() has not been implemented.');
  }

  Future<void> setFeedThreshold(int threshold) {
    throw UnimplementedError('setFeedThreshold() has not been implemented.');
  }

  Future<void> release() {
    throw UnimplementedError('release() has not been implemented.');
  }

  void setFeedCallback(Function(int)? callback) {
    throw UnimplementedError('setFeedCallback() has not been implemented.');
  }

  Future<void> setVolume(double volume) {
    throw UnimplementedError('setVolume() has not been implemented.');
  }

  Future<double> getVolume() {
    throw UnimplementedError('getVolume() has not been implemented.');
  }
}
