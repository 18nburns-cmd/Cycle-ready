import 'package:cycle_ready/src/features/updates/data/github_app_release_repository.dart';
import 'package:cycle_ready/src/features/updates/domain/app_release.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appReleaseRepositoryProvider =
    Provider<AppReleaseRepository>((ref) => GithubAppReleaseRepository());

final appReleaseProvider = FutureProvider<AppRelease>(
  (ref) => ref.watch(appReleaseRepositoryProvider).check(),
);
