import 'package:flutter_pcm_sound_fork/flutter_pcm_sound_platform_interface.dart';
import 'package:flutter_pcm_sound_fork/pcm_array_int16.dart';

export 'package:flutter_pcm_sound_fork/major_scale.dart';
export 'package:flutter_pcm_sound_fork/flutter_pcm_sound_platform_interface.dart';
export 'package:flutter_pcm_sound_fork/pcm_array_int16.dart';

class FlutterPcmSound {
  static Future<void> setLogLevel(LogLevel level) {
    return FlutterPcmSoundPlatform.instance.setLogLevel(level);
  }

  static Future<void> resumeAudioContext() {
    return FlutterPcmSoundPlatform.instance.resumeAudioContext();
  }

  static Future<void> setup(
      {required int sampleRate,
      required int channelCount,
      IosAudioCategory iosAudioCategory = IosAudioCategory.playback}) {
    return FlutterPcmSoundPlatform.instance.setup(
      sampleRate: sampleRate,
      channelCount: channelCount,
      iosAudioCategory: iosAudioCategory,
    );
  }

  static Future<void> feed(PcmArrayInt16 buffer) {
    return FlutterPcmSoundPlatform.instance.feed(buffer);
  }

  static Future<void> clearBuffer({bool force = false}) {
    return FlutterPcmSoundPlatform.instance.clearBuffer(force: force);
  }

  static Future<void> setFeedThreshold(int threshold) {
    return FlutterPcmSoundPlatform.instance.setFeedThreshold(threshold);
  }

  static void setFeedCallback(Function(int)? callback) {
    FlutterPcmSoundPlatform.instance.setFeedCallback(callback);
  }

  static void start() {
    FlutterPcmSoundPlatform.instance.setFeedCallback((remainingFrames) {
      onFeedSamplesCallback?.call(remainingFrames);
    });
  }

  static Future<void> release() {
    return FlutterPcmSoundPlatform.instance.release();
  }

  static Function(int)? onFeedSamplesCallback;

  static Future<void> setVolume(double volume) {
    return FlutterPcmSoundPlatform.instance.setVolume(volume);
  }

  static Future<double> getVolume() {
    return FlutterPcmSoundPlatform.instance.getVolume();
  }
}
