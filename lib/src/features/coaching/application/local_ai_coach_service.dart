import 'dart:async';
import 'dart:convert';

import 'package:llama_flutter_android/llama_flutter_android.dart';

const localCoachSystemPrompt =
    '''You are an evidence-based cycling training assistant built into a cycling and health app.

Your role is to explain the user's calculated training, recovery and cycling metrics clearly.

Never invent measurements. Never claim a metric was measured if it was not supplied. Do not recalculate supplied scores such as readiness, TSS, FTP or training load. Base your assessment only on the data supplied by the application. Prioritise the athlete's personal baseline and recent trends. Explain why something matters rather than simply repeating numbers. Give practical cycling advice. Be conservative when recovery indicators are poor. Do not diagnose illnesses, injuries or medical conditions. When metrics could indicate illness, overtraining or another medical issue, explain that the data alone cannot determine the cause and recommend appropriate professional advice where necessary. Keep feedback concise, supportive and useful. Use British English.

Speak like a thoughtful human coach who knows the rider well. Address the rider directly as "you". Lead with the practical takeaway, then explain the two or three strongest reasons. Use natural contractions where appropriate and vary sentence length. Be warm and calm without exaggerated praise. Do not sound clinical, corporate or like a data report. Never say "the user", "the athlete", "the supplied data", "the metrics indicate" or "based on the data". Do not list every number. Mention a number only when it genuinely helps the rider understand the advice. Avoid repeating the readiness score or recommendation more than once. Treat power momentum as supporting context: a lower curve may reflect fatigue or no recent maximal effort, and must never override poor recovery signals.

Return valid JSON with headline, summary, keyFactors (array), recommendation and confidence. The headline should sound like something a real coach would say and contain no more than ten words. The summary should be two short, conversational paragraphs. Include at most three key factors, written naturally. The recommendation should be one clear, practical next step. If a value is absent, do not mention it.''';

String buildLocalCoachPrompt({
  required String task,
  required Map<String, Object?> data,
  String? question,
}) {
  final taskDirection = switch (task) {
    "Today's Readiness" =>
      'Tell the rider how prepared they look today and what matters most. Do not simply repeat the score.',
    "Today's Recommendation" =>
      'Start with what the rider should do today. Then briefly explain why that choice fits their recent training and recovery.',
    'Analyse My Latest Ride' =>
      'Give a short post-ride conversation: what went well, what was demanding, and the most useful next step.',
    'Weekly Training Review' =>
      'Talk through the week as a coach would after training: one success, one useful caution, and the priority for next week.',
    'Fitness Trend' =>
      'Explain the direction of fitness in plain language and suggest one practical way to keep improving.',
    'Recovery Analysis' =>
      'Explain the recovery picture gently, focusing on what the rider can do rather than reciting measurements.',
    _ =>
      'Answer the question directly first, then use only the most relevant personal training information to explain it.',
  };
  return 'Coaching task: $task\n'
      '${question == null || question.trim().isEmpty ? '' : 'Rider asks: ${question.trim()}\n'}'
      '$taskDirection\n'
      'Private application-calculated context: ${jsonEncode(data)}\n'
      'Keep this concise, personal and natural. Preserve the application safety recommendation.';
}

class LocalCoachResponse {
  const LocalCoachResponse({
    required this.headline,
    required this.summary,
    required this.keyFactors,
    required this.recommendation,
    required this.confidence,
    required this.rawText,
  });
  final String headline;
  final String summary;
  final List<String> keyFactors;
  final String recommendation;
  final String confidence;
  final String rawText;

  static LocalCoachResponse parse(String text) {
    try {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      final json = jsonDecode(text.substring(start, end + 1));
      if (json is! Map<String, dynamic>) throw const FormatException();
      final headline = json['headline'];
      final summary = json['summary'];
      final recommendation = json['recommendation'];
      if (headline is! String ||
          summary is! String ||
          recommendation is! String) {
        throw const FormatException();
      }
      return LocalCoachResponse(
        headline: headline,
        summary: summary,
        keyFactors: (json['keyFactors'] as List? ?? const [])
            .whereType<String>()
            .take(6)
            .toList(),
        recommendation: recommendation,
        confidence: json['confidence'] is String
            ? json['confidence'] as String
            : 'medium',
        rawText: text,
      );
    } catch (_) {
      return LocalCoachResponse(
        headline: 'Local coach analysis',
        summary: text.trim(),
        keyFactors: const [],
        recommendation:
            'Follow the deterministic recommendation shown by CycleReady.',
        confidence: 'unstructured',
        rawText: text,
      );
    }
  }
}

class LocalAiCoachService {
  LlamaController _controller = LlamaController();
  String? _loadedPath;
  bool _busy = false;

  bool get isBusy => _busy;

  Future<void> load(String modelPath) async {
    if (_loadedPath == modelPath && await _controller.isModelLoaded()) return;
    if (await _controller.isModelLoaded()) {
      throw StateError('A different local model is already loaded.');
    }
    final gpu = await _controller.detectGpu();
    if (gpu.freeRamBytes > 0 && gpu.freeRamBytes < 700 * 1024 * 1024) {
      throw StateError('Not enough free memory to load the local AI model.');
    }
    await _controller.loadModel(
      modelPath: modelPath,
      threads: 4,
      contextSize: 3072,
      gpuLayers: gpu.recommendedGpuLayers,
    );
    _loadedPath = modelPath;
  }

  Stream<String> generate({
    required String modelPath,
    required String task,
    required Map<String, Object?> data,
    String? question,
  }) async* {
    if (_busy) throw StateError('The local coach is already responding.');
    _busy = true;
    try {
      await load(modelPath);
      final prompt = buildLocalCoachPrompt(
        task: task,
        data: data,
        question: question,
      );
      yield* _controller.generateChat(
        messages: [
          ChatMessage(role: 'system', content: localCoachSystemPrompt),
          ChatMessage(role: 'user', content: prompt),
        ],
        template: 'chatml',
        maxTokens: 480,
        temperature: .45,
        topP: .92,
        repeatPenalty: 1.1,
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> cancel() => _controller.stop();
  Future<void> unload() async {
    await _controller.dispose();
    _controller = LlamaController();
    _loadedPath = null;
    _busy = false;
  }

  Future<void> dispose() => _controller.dispose();
}
