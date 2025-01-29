import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_pcm_sound/flutter_pcm_sound_platform_interface.dart';
import 'package:flutter_pcm_sound/pcm_array_int16.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart';

// JS interop types
@JS('AudioContext')
external JSFunction get _audioContextConstructor;

@JS('AudioWorkletNode')
external JSFunction get _audioWorkletNodeConstructor;

@JS('Blob')
external JSFunction get _blobConstructor;

@JS('URL.createObjectURL')
external String _createObjectURL(JSObject blob);

@JS('URL.revokeObjectURL')
external void _revokeObjectURL(String url);

// Extension types
extension type AudioContext._(JSObject _) implements JSObject {
  external factory AudioContext({int? sampleRate});
  external AudioWorklet get audioWorklet;
  external JSAny get destination;
  external JSString get state;
  external JSFunction get resume;
  external JSFunction get close;
}

extension type AudioWorklet._(JSObject _) implements JSObject {
  external JSPromise addModule(String moduleURL);
}

extension type AudioWorkletNode._(JSObject _) implements JSObject {
  external factory AudioWorkletNode(AudioContext context, String name, JSObject options);
  external MessagePort get port;
  external void connect(JSAny destination);
  external void disconnect();
}

extension type MessagePort._(JSObject _) implements JSObject {
  external void postMessage(JSAny message, [JSArray? transfer]);
  external set onmessage(JSFunction? callback);
}

/// Web implementation of the flutter_pcm_sound plugin.
class FlutterPcmSoundWeb extends FlutterPcmSoundPlatform {
  static void registerWith(Registrar registrar) {
    FlutterPcmSoundPlatform.instance = FlutterPcmSoundWeb();
  }

  AudioContext? _audioContext;
  AudioWorkletNode? _workletNode;
  Function(int)? _onFeedCallback;
  LogLevel _logLevel = LogLevel.standard;
  bool _isInitialized = false;
  Completer<void>? _setupCompleter;
  bool get isReady => _audioContext?.state.toDart == 'running';
  int? _pendingSampleRate;
  int? _pendingChannelCount;

  @override
  Future<void> setLogLevel(LogLevel level) async {
    _logLevel = level;
    _log('Log level set to: $level');
  }

  @override
  Future<void> resumeAudioContext() async {
    if (!_isInitialized) {
      throw Exception('PCM Sound not initialized');
    }

    try {
      // Initialize context if needed
      if (_audioContext == null) {
        await _initializeAudioContext();
      }

      if (_audioContext!.state.toDart != 'running') {
        final resumeFunc = _audioContext!.resume;
        final jsThis = _audioContext as JSObject;
        await (resumeFunc.callAsFunction(jsThis) as JSPromise).toDart;
        _log('AudioContext resumed successfully');
      }
    } catch (e) {
      _log('Failed to resume AudioContext: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> setup({
    required int sampleRate,
    required int channelCount,
    IosAudioCategory iosAudioCategory = IosAudioCategory.playback
  }) async {
    if (_setupCompleter?.isCompleted == false) {
      return _setupCompleter!.future;
    }
    _setupCompleter = Completer<void>();

    try {
      _log('Setting up PCM Sound with sample rate: $sampleRate, channel count: $channelCount');

      // Store parameters for later initialization
      _pendingSampleRate = sampleRate;
      _pendingChannelCount = channelCount;
      _isInitialized = true;
      _setupCompleter?.complete();

      _log('PCM Sound setup completed');

    } catch (e) {
      _log('Failed to setup PCM Sound: $e', LogLevel.error);
      _setupCompleter?.completeError(e);
      await release();
      rethrow;
    }
  }

  Future<void> _initializeAudioContext() async {
    if (_isIOSBrowser()) {
      _log('Initializing on iOS WebKit-based browser');
      try {
        if (_audioContext == null) {
          final ctx = _audioContextConstructor.callAsConstructor({
            'sampleRate': _pendingSampleRate,
            'latencyHint': 'playback'
          }.jsify());

          if (ctx == null) throw Exception('Failed to create AudioContext');
          _audioContext = ctx as AudioContext;

          // Force a user interaction before proceeding
          await _ensureUserGesture();

          // Initialize worklet with additional error handling
          await _initializeWorkletSafely(_pendingChannelCount!);
        }
      } catch (e) {
        _log('iOS AudioContext initialization failed: $e', LogLevel.error);
        rethrow;
      }
    } else {
      if (_audioContext == null) {
        final ctx = _audioContextConstructor.callAsConstructor({
          'sampleRate': _pendingSampleRate
        }.jsify());
        if (ctx == null) throw Exception('Failed to create AudioContext');
        _audioContext = ctx as AudioContext;

        // Initialize worklet after creating context
        await _initializeWorklet(_pendingChannelCount!);
      }
    }
  }

  bool _isIOSBrowser() {
    final userAgent = window.navigator.userAgent.toLowerCase();
    return userAgent.contains('iphone') || userAgent.contains('ipad') || userAgent.contains('ipod');
  }

  Future<void> _ensureUserGesture() async {
    if (_audioContext?.state.toDart != 'running') {
      _log('Waiting for user gesture to enable audio...');
      // You might want to show UI here requesting user interaction
      final resumeFunc = _audioContext!.resume;
      final jsThis = _audioContext as JSObject;
      try {
        await (resumeFunc.callAsFunction(jsThis) as JSPromise).toDart;
      } catch (e) {
        _log('Resume failed: $e', LogLevel.error);
        rethrow;
      }
    }
  }

  Future<void> _initializeWorkletSafely(int channelCount) async {
    try {
      final processorCode = _generateProcessorCode();
      final blob = _createBlob(processorCode);
      final url = _createObjectURL(blob);

      try {
        final workletPromise = _audioContext!.audioWorklet.addModule(url);

        _log('Waiting for worklet module to load...');
        await workletPromise.toDart;
        _log('Worklet module loaded successfully');

        final options = _createWorkletOptions(channelCount);
        final node = _audioWorkletNodeConstructor.callAsConstructor(
            _audioContext,
            'pcm-player'.toJS,
            options
        );

        if (node == null) throw Exception('Failed to create AudioWorkletNode');
        _workletNode = node as AudioWorkletNode;

        _setupMessageHandling();
        _workletNode!.connect(_audioContext!.destination);

      } finally {
        _revokeObjectURL(url);
      }
    } catch (e) {
      _log('Worklet initialization failed: $e', LogLevel.error);
      rethrow;
    }
  }

  Future<void> _initializeWorklet(int channelCount) async {
    final processorCode = _generateProcessorCode();
    final blob = _createBlob(processorCode);
    final url = _createObjectURL(blob);

    try {
      await _audioContext!.audioWorklet.addModule(url).toDart;

      final options = _createWorkletOptions(channelCount);
      final node = _audioWorkletNodeConstructor.callAsConstructor(
          _audioContext,
          'pcm-player'.toJS,
          options
      );

      if (node == null) throw Exception('Failed to create AudioWorkletNode');
      _workletNode = node as AudioWorkletNode;

      _setupMessageHandling();
      _workletNode!.connect(_audioContext!.destination);

      final configMessage = _createMessageData('config', {
        'channelCount': channelCount,
      });
      _workletNode!.port.postMessage(configMessage);

    } finally {
      _revokeObjectURL(url);
    }
  }

  @override
  Future<void> feed(PcmArrayInt16 buffer) async {
    if (!_isInitialized || _workletNode == null) {
      throw Exception('PCM Sound not initialized');
    }

    if (_audioContext?.state.toDart != 'running') {
      _log('Warning: AudioContext not running, audio may not play', LogLevel.error);
    }

    final bufferLength = buffer.bytes.lengthInBytes;
    _log('Feeding $bufferLength bytes');

    if (bufferLength > 0) {
      try {
        // Get the raw buffer data
        final rawBuffer = buffer.bytes.buffer.asUint8List(
            buffer.bytes.offsetInBytes,
            buffer.bytes.lengthInBytes
        );
        _log('Raw buffer created with ${rawBuffer.length} bytes');

        // Create ArrayBuffer for transfer
        final jsArray = Uint8List.fromList(rawBuffer);
        _log('Created transferable array with ${jsArray.length} bytes');

        // Debug: Log first few samples
        final sampleDebug = StringBuffer('First few samples: ');
        for (var i = 0; i < min(5, bufferLength ~/ 2); i++) {
          if (i > 0) sampleDebug.write(', ');
          sampleDebug.write(buffer.bytes.getInt16(i * 2, Endian.little));
        }
        _log(sampleDebug.toString());

        // Create message with buffer
        final message = _createMessageData('feed', {
          'buffer': jsArray.buffer
        });

        // Post message to worklet node
        _workletNode!.port.postMessage(message);

      } catch (e, stack) {
        _log('Error in feed: $e\n$stack', LogLevel.error);
        rethrow;
      }
    } else {
      _log('Warning: Received empty buffer', LogLevel.error);
    }
  }

  @override
  Future<void> setFeedThreshold(int threshold) async {
    if (_workletNode == null) return;

    final message = _createMessageData('config', {
      'feedThreshold': threshold
    });

    _workletNode!.port.postMessage(message);
  }

  @override
  void setFeedCallback(Function(int)? callback) {
    _onFeedCallback = callback;
  }

  @override
  Future<void> clearBuffer() async {
    if (_workletNode == null) return;

    final message = _createMessageData('clear', {});
    _workletNode!.port.postMessage(message);
    _log('Clear buffer command sent to worklet');
  }

  @override
  Future<void> release() async {
    if (_workletNode != null) {
      _workletNode!.disconnect();
      _workletNode = null;
    }

    if (_audioContext != null) {
      try {
        final closeFunc = _audioContext!.close;
        final jsThis = _audioContext as JSObject;
        await (closeFunc.callAsFunction(jsThis) as JSPromise).toDart;
      } catch (e) {
        _log('Error closing AudioContext: $e', LogLevel.error);
      }
      _audioContext = null;
    }

    _onFeedCallback = null;
    _log('PCM Sound released');
  }

  // Private helper methods
  JSObject _createWorkletOptions(int channelCount) {
    return {
      'numberOfInputs': 0,
      'numberOfOutputs': 1,
      'outputChannelCount': [channelCount]
    }.jsify() as JSObject;
  }

  JSObject _createMessageData(String type, Map<String, dynamic> data) {
    return {
      'type': type,
      'data': data
    }.jsify() as JSObject;
  }

  void _setupMessageHandling() {
    _workletNode!.port.onmessage = ((JSAny messageEvent) {
      try {
        final event = messageEvent as MessageEvent;
        // First convert to Map<Object?, Object?>
        final rawData = event.data.dartify() as Map<Object?, Object?>;

        // Then safely convert to Map<String, dynamic>
        final data = Map<String, dynamic>.fromEntries(
            rawData.entries.map((entry) => MapEntry(
                entry.key?.toString() ?? '',
                entry.value
            ))
        );

        //print('Received message: $data');

        if (data['type'] == 'needMore' && _onFeedCallback != null) {
          // Safely cast the remaining value
          final remaining = (data['remaining'] as num).toInt();
          _onFeedCallback!(remaining);
        }
      } catch (e, stack) {
        _log('Error processing message: $e\n$stack', LogLevel.error);
      }
    }).toJS;
  }

  JSObject _createBlob(String content) {
    final array = [content].jsify() as JSArray;
    final options = {'type': 'text/javascript'}.jsify() as JSObject;
    return _blobConstructor.callAsConstructor(array, options);
  }

  String _generateProcessorCode() {
    return '''
  class PCMPlayer extends AudioWorkletProcessor {
    constructor() {
      super();
      console.log('PCMPlayer: Initialized from _generateProcessorCode');

      this.buffer = new Float32Array(0);
      this.channelCount = 1;
      this.feedThreshold = 4096;
      this.sampleCount = 0;
      this.isClearing = false;
      this.clearingSampleCount = 0;
      this.samplesUntilClearingDone = 2048; // About 50ms worth of samples at 44.1kHz

      this.port.onmessage = (event) => {
        const {type, data} = event.data;
        console.log(`PCMPlayer: Received event of type: \${type}`);
        
        if (type === 'config') {
          console.log('PCMPlayer: Received config:', data);
          if (data.channelCount != null) {
            this.channelCount = data.channelCount;
          }
          if (data.feedThreshold != null) {
            this.feedThreshold = data.feedThreshold;
          }
        } else if (type === 'clear') {
          console.log('PCMPlayer: Clearing buffer');
          // Set clearing state
          this.isClearing = true;
          this.clearingSampleCount = 0;

          // Clear existing buffer
          this.buffer = new Float32Array(0);

          // Notify that buffer was cleared
          this.port.postMessage({
            type: 'bufferCleared'
          });
        } else if (type === 'feed') {
          // Drop incoming audio during clearing state
          if (this.isClearing) {
            console.log('PCMPlayer: Dropping feed during clear operation');
            return;
          }

          console.log('PCMPlayer: Received feed data of length:', data.buffer.byteLength);

          // Create DataView for proper byte handling
          const dataView = new DataView(data.buffer);
          const float32Data = new Float32Array(data.buffer.byteLength / 2);

          // Convert Int16 to Float32 with proper endianness
          for (let i = 0; i < float32Data.length; i++) {
            const int16Sample = dataView.getInt16(i * 2, true); // true = little-endian
            float32Data[i] = int16Sample / 32768.0;
          }

          // Create new buffer with combined data
          const newBuffer = new Float32Array(this.buffer.length + float32Data.length);
          newBuffer.set(this.buffer);
          newBuffer.set(float32Data, this.buffer.length);
          this.buffer = newBuffer;
        }
      };
    }

    process(inputs, outputs) {
      const output = outputs[0];
      const channelCount = Math.min(output.length, this.channelCount);
      const samplesPerChannel = output[0].length;

      this.sampleCount += samplesPerChannel;

      // Handle clearing state
      if (this.isClearing) {
        this.clearingSampleCount += samplesPerChannel;
        if (this.clearingSampleCount >= this.samplesUntilClearingDone) {
          console.log('PCMPlayer: Clearing state complete');
          this.isClearing = false;
          this.clearingSampleCount = 0;
        }

        // Output silence during clearing
        for (let channel = 0; channel < channelCount; channel++) {
          output[channel].fill(0);
        }
        return true;
      }

      // Log processing state periodically
      if (this.sampleCount % (sampleRate / 2) === 0) {
        console.log('PCMPlayer: Processing state:', {
          bufferLength: this.buffer.length,
          channelCount,
          samplesPerChannel,
          totalProcessed: this.sampleCount,
          isClearing: this.isClearing
        });
      }

      // Request more data if buffer is running low
      if (this.buffer.length < this.feedThreshold) {
        this.port.postMessage({
          type: 'needMore',
          remaining: this.buffer.length
        });
      }

      // Output silence if buffer is empty
      if (this.buffer.length === 0) {
        for (let channel = 0; channel < channelCount; channel++) {
          output[channel].fill(0);
        }
        return true;
      }

      // Process audio data
      let didOutput = false;
      for (let channel = 0; channel < channelCount; channel++) {
        const outputChannel = output[channel];

        if (this.buffer.length >= outputChannel.length) {
          outputChannel.set(this.buffer.subarray(0, outputChannel.length));
          this.buffer = this.buffer.subarray(outputChannel.length);
          didOutput = true;
        } else {
          outputChannel.set(this.buffer);
          outputChannel.fill(0, this.buffer.length);
          this.buffer = new Float32Array(0);
          didOutput = true;
        }
      }

      // Log output state periodically
      if (didOutput && this.sampleCount % (sampleRate / 10) === 0) {
        console.log('PCMPlayer: Audio output active:', {
          remainingBuffer: this.buffer.length,
          didOutput,
          timestamp: currentTime,
          isClearing: this.isClearing
        });
      }

      return true;
    }
  }

  registerProcessor('pcm-player', PCMPlayer);
''';
  }

  void _log(String message, [LogLevel level = LogLevel.standard]) {
    if (level.index <= _logLevel.index) {
      print('[PCM${level == LogLevel.error ? ' ERROR' : ''}] $message');
    }
  }
}