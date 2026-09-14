class PushMessage {
  const PushMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.route,
  });

  final String id;
  final String title;
  final String body;
  final String route;

  factory PushMessage.fromData(Map<String, dynamic> data) => PushMessage(
        id: '${data['notification_id'] ?? ''}',
        title: '${data['title'] ?? 'CycleReady'}',
        body: '${data['body'] ?? 'Your coaching has been updated.'}',
        route: safeNotificationRoute('${data['route'] ?? '/'}'),
      );
}

String safeNotificationRoute(String value) {
  const allowed = <String>{
    '/',
    '/coach',
    '/nutrition',
    '/performance',
    '/training-plan',
    '/connect',
  };
  if (allowed.contains(value)) return value;
  if (RegExp(r'^/activities/[A-Za-z0-9_-]+(?:/debrief)?$').hasMatch(value)) {
    return value;
  }
  return '/';
}
