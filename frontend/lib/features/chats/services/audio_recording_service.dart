import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'media_picker_service.dart';

/// Records audio messages and returns them as media files ready for upload.
class AudioRecordingService {
  AudioRecordingService._();

  static final AudioRecordingService instance = AudioRecordingService._();

  final AudioRecorder _recorder = AudioRecorder();
  String? _activeRecordingPath;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  Future<void> startRecording() async {
    if (_isRecording) {
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission denied');
    }

    final tempDir = await getTemporaryDirectory();
    final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.wav';
    final filePath = path.join(tempDir.path, fileName);

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: filePath,
    );

    _activeRecordingPath = filePath;
    _isRecording = true;
  }

  Future<PickedMediaFile> stopRecording() async {
    if (!_isRecording) {
      throw Exception('No active audio recording');
    }

    final stoppedPath = await _recorder.stop();
    final resolvedPath = stoppedPath ?? _activeRecordingPath;
    _activeRecordingPath = null;
    _isRecording = false;

    if (resolvedPath == null) {
      throw Exception('Recorder returned no file path');
    }

    final file = File(resolvedPath);
    if (!await file.exists()) {
      throw Exception('Recorded audio file not found');
    }

    final bytes = await file.readAsBytes();
    final fileName = path.basename(resolvedPath);

    return PickedMediaFile(
      name: fileName,
      path: resolvedPath,
      bytes: bytes,
      mimeType: 'audio/wav',
      sizeBytes: bytes.length,
    );
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) {
      return;
    }

    await _recorder.stop();
    _activeRecordingPath = null;
    _isRecording = false;
  }
}
