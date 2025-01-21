
import 'package:flutter/material.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PcmSoundApp();
  }
}

class PcmSoundApp extends StatefulWidget {
  @override
  _PcmSoundAppState createState() => _PcmSoundAppState();
}

class _PcmSoundAppState extends State<PcmSoundApp> {

  static const int sampleRate = 48000;
  bool _isAudioReady = false;
  int _remainingFrames = 0;
  bool _isPlaying = false;

  MajorScale scale = MajorScale(sampleRate: sampleRate, noteDuration: 0.20);

  @override
  void initState() {
    WidgetsFlutterBinding.ensureInitialized();
    super.initState();
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    try {
      await FlutterPcmSound.setLogLevel(LogLevel.verbose);
      await FlutterPcmSound.setup(sampleRate: sampleRate, channelCount: 1);
      await FlutterPcmSound.setFeedThreshold(sampleRate ~/ 10);
    } catch (e) {
      print('Failed to initialize audio: $e');
    }
  }

  Future<void> _startAudio() async {
    try {
      await FlutterPcmSound.resumeAudioContext();
      setState(() => _isAudioReady = true);
    } catch (e) {
      print('Failed to start audio: $e');
    }
  }

  Future<void> _playAudio() async {
    if (!_isAudioReady) {
      await _startAudio();
    }
    setState(() => _isPlaying = true);
    FlutterPcmSound.setFeedCallback(_onFeed);
    _onFeed(0);
  }

  void _stopAudio() {
    setState(() => _isPlaying = false);
    FlutterPcmSound.setFeedCallback(null);
    setState(() => _remainingFrames = 0);
  }

  @override
  void dispose() {
    super.dispose();
    FlutterPcmSound.release();
  }

  void _onFeed(int remainingFrames) async {
    setState(() {
      _remainingFrames = remainingFrames;
    });
    List<int> frames = scale.generate(periods: 20);
    await FlutterPcmSound.feed(PcmArrayInt16.fromList(frames));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text('Flutter PCM Sound'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (!_isAudioReady)
                ElevatedButton(
                  onPressed: _startAudio,
                  child: Text('Initialize Audio'),
                ),
              ElevatedButton(
                onPressed: _isPlaying ? null : _playAudio,
                child: Text('Play'),
              ),
              ElevatedButton(
                onPressed: _isPlaying ? _stopAudio : null,
                child: Text('Stop'),
              ),
              Text('$_remainingFrames Remaining Frames'),
              if (!_isAudioReady)
                Text('Click Initialize Audio to start',
                    style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}