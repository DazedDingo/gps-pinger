import 'dart:convert';
import 'dart:io';

import 'github_pat_service.dart';

/// Thin wrapper around the small slice of the GitHub REST API we use:
/// firing `workflow_dispatch` for `build-region.yml` from inside the
/// app. Auth is the user's PAT stored via [GithubPatService]; if no
/// token is present every method throws [GithubAuthMissingError] so
/// the caller can route to the Settings flow.
class GithubApi {
  static const _owner = 'DazedDingo';
  static const _repo = 'trail';
  static const _workflowFile = 'build-region.yml';
  static const _userAgent = 'Trail/0.8 (region-build dispatch)';

  /// Triggers `build-region.yml` against `main`. Returns when GitHub
  /// has accepted the dispatch (HTTP 204); the caller can then ask the
  /// user to wait ~10–20 min for the build itself.
  static Future<void> dispatchRegionBuild({
    required String name,
    required String bbox,
    required String maxzoom,
    required String area,
    String description = '',
    HttpClient? httpClient,
  }) async {
    final pat = await _requirePat();
    final client = httpClient ?? HttpClient();
    try {
      final req = await client.postUrl(Uri.parse(
        'https://api.github.com/repos/$_owner/$_repo/actions/workflows/'
        '$_workflowFile/dispatches',
      ));
      _setStandardHeaders(req, pat);
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode({
        'ref': 'main',
        'inputs': {
          'name': name,
          'bbox': bbox,
          'maxzoom': maxzoom,
          'area': area,
          'description': description,
        },
      })));
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      if (resp.statusCode != 204) {
        throw GithubApiError(
          'dispatch failed: HTTP ${resp.statusCode} $body',
        );
      }
    } finally {
      if (httpClient == null) client.close();
    }
  }

  /// Calls /user to confirm the PAT is valid + has the right scopes.
  /// Returns the authenticated login name. Throws on auth/network
  /// failures so the Settings UI can surface a useful error.
  static Future<String> verifyToken({HttpClient? httpClient}) async {
    final pat = await _requirePat();
    final client = httpClient ?? HttpClient();
    try {
      final req =
          await client.getUrl(Uri.parse('https://api.github.com/user'));
      _setStandardHeaders(req, pat);
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      if (resp.statusCode != 200) {
        throw GithubApiError(
          'token check failed: HTTP ${resp.statusCode} $body',
        );
      }
      final json = jsonDecode(body);
      if (json is Map && json['login'] is String) {
        return json['login'] as String;
      }
      throw const GithubApiError('token check: malformed response');
    } finally {
      if (httpClient == null) client.close();
    }
  }

  static Future<String> _requirePat() async {
    final pat = await GithubPatService.read();
    if (pat == null || pat.isEmpty) {
      throw const GithubAuthMissingError();
    }
    return pat;
  }

  static void _setStandardHeaders(HttpClientRequest req, String pat) {
    req.headers
      ..set('Accept', 'application/vnd.github+json')
      ..set('Authorization', 'Bearer $pat')
      ..set('X-GitHub-Api-Version', '2022-11-28')
      ..set('User-Agent', _userAgent);
  }
}

class GithubAuthMissingError implements Exception {
  const GithubAuthMissingError();
  @override
  String toString() =>
      'No GitHub token configured. Settings → Build region access.';
}

class GithubApiError implements Exception {
  final String message;
  const GithubApiError(this.message);
  @override
  String toString() => 'GitHub API: $message';
}
