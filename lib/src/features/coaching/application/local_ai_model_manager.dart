import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalAiModelInfo {
  const LocalAiModelInfo({
    required this.id,
    required this.name,
    required this.fileName,
    required this.url,
    required this.sizeBytes,
    required this.sha256,
  });
  final String id;
  final String name;
  final String fileName;
  final Uri url;
  final int sizeBytes;
  final String sha256;
}

final defaultLocalAiModel = LocalAiModelInfo(
  id: 'qwen2.5-0.5b-instruct-q4-k-m',
  name: 'Qwen2.5 0.5B Instruct Q4_K_M',
  fileName: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
  url: Uri.parse(
    'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
  ),
  sizeBytes: 491400032,
  sha256: '74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db',
);

class LocalAiModelState {
  const LocalAiModelState({
    this.installed = false,
    this.downloading = false,
    this.progress = 0,
    this.path,
    this.storageUsedBytes = 0,
    this.error,
  });
  final bool installed;
  final bool downloading;
  final double progress;
  final String? path;
  final int storageUsedBytes;
  final String? error;

  LocalAiModelState copyWith({
    bool? installed,
    bool? downloading,
    double? progress,
    String? path,
    int? storageUsedBytes,
    String? error,
    bool clearError = false,
  }) =>
      LocalAiModelState(
        installed: installed ?? this.installed,
        downloading: downloading ?? this.downloading,
        progress: progress ?? this.progress,
        path: path ?? this.path,
        storageUsedBytes: storageUsedBytes ?? this.storageUsedBytes,
        error: clearError ? null : error ?? this.error,
      );
}

final localAiModelManagerProvider =
    StateNotifierProvider<LocalAiModelManager, LocalAiModelState>((ref) {
  final manager = LocalAiModelManager(defaultLocalAiModel)..refresh();
  return manager;
});

class LocalAiModelManager extends StateNotifier<LocalAiModelState> {
  LocalAiModelManager(this.model) : super(const LocalAiModelState());
  final LocalAiModelInfo model;
  static const _device = MethodChannel('cycle_ready/device');
  HttpClient? _client;
  bool _cancelled = false;

  Future<Directory> get _directory async {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'local_ai'));
  }

  Future<File> get _modelFile async =>
      File(p.join((await _directory).path, model.fileName));

  Future<void> refresh() async {
    final file = await _modelFile;
    final marker = File('${file.path}.verified');
    final installed = await file.exists() &&
        await marker.exists() &&
        await file.length() == model.sizeBytes;
    state = LocalAiModelState(
      installed: installed,
      path: installed ? file.path : null,
      storageUsedBytes: await file.exists() ? await file.length() : 0,
    );
  }

  Future<void> download() async {
    if (state.downloading || state.installed) return;
    state = state.copyWith(
      downloading: true,
      progress: 0,
      clearError: true,
    );
    _cancelled = false;
    try {
      final free = await _device.invokeMethod<int>('freeStorageBytes');
      if (free != null && free < model.sizeBytes + 200 * 1024 * 1024) {
        throw StateError('At least 700 MB of free storage is required.');
      }
      final directory = await _directory;
      await directory.create(recursive: true);
      final target = await _modelFile;
      final temporary = File('${target.path}.download');
      if (await temporary.exists()) await temporary.delete();
      _client = HttpClient();
      final request = await _client!.getUrl(model.url);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Model download returned ${response.statusCode}.');
      }
      final output = temporary.openWrite();
      var received = 0;
      await for (final chunk in response) {
        if (_cancelled) throw const _DownloadCancelled();
        output.add(chunk);
        received += chunk.length;
        state = state.copyWith(
          progress: (received / model.sizeBytes).clamp(0, 1),
          storageUsedBytes: received,
        );
      }
      await output.close();
      if (received != model.sizeBytes) {
        throw StateError('The downloaded model has an unexpected size.');
      }
      final digest = await _sha256(temporary);
      if (digest != model.sha256) {
        throw StateError('Model verification failed. Please download again.');
      }
      if (await target.exists()) await target.delete();
      await temporary.rename(target.path);
      await File('${target.path}.verified').writeAsString(model.sha256);
      state = LocalAiModelState(
        installed: true,
        path: target.path,
        progress: 1,
        storageUsedBytes: model.sizeBytes,
      );
    } catch (error) {
      state = LocalAiModelState(
        error: error is _DownloadCancelled
            ? 'Download cancelled.'
            : error.toString().replaceFirst('Bad state: ', ''),
      );
    } finally {
      _client?.close(force: true);
      _client = null;
    }
  }

  Future<void> cancelDownload() async {
    _cancelled = true;
    _client?.close(force: true);
  }

  Future<void> deleteModel() async {
    await cancelDownload();
    final file = await _modelFile;
    for (final path in [
      file.path,
      '${file.path}.verified',
      '${file.path}.download'
    ]) {
      final candidate = File(path);
      if (await candidate.exists()) await candidate.delete();
    }
    state = const LocalAiModelState();
  }

  Future<String> _sha256(File file) async {
    Digest? result;
    final sink = sha256.startChunkedConversion(
      ChunkedConversionSink.withCallback((values) => result = values.single),
    );
    await for (final chunk in file.openRead()) {
      sink.add(chunk);
    }
    sink.close();
    return result.toString();
  }
}

class _DownloadCancelled implements Exception {
  const _DownloadCancelled();
}
