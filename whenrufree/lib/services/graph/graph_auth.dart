import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/graph_config.dart';

class GraphAuthException implements Exception {
  final String message;
  const GraphAuthException(this.message);
  @override
  String toString() => 'GraphAuthException: $message';
}

/// Microsoft sign-in with PKCE (public client — no secret anywhere).
///
/// Privacy design (no-data-stored): ONLY the OAuth refresh token is persisted
/// (in platform secure storage). Access tokens live in memory, calendar
/// events are fetched on demand and only saved as lessons when the user
/// explicitly taps Import.
class GraphAuth {
  GraphAuth._();
  static final GraphAuth instance = GraphAuth._();

  static const _kClientIdOverride = 'wrf_graph_client_id';
  static const _kRefresh = 'wrf_ms_refresh_token';
  static const _kRefreshClient = 'wrf_ms_refresh_client';

  static const _storage = FlutterSecureStorage();

  String? _accessToken;
  DateTime? _accessExpiresAt;
  String? _lastVerifier;

  // ---------- configuration ----------

  Future<String> effectiveClientId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final override = (prefs.getString(_kClientIdOverride) ?? '').trim();
      if (override.isNotEmpty) return override;
    } catch (_) {}
    return kBundledClientId.trim();
  }

  Future<bool> isConfigured() async =>
      (await effectiveClientId()).isNotEmpty;

  Future<void> setClientIdOverride(String clientId) async {
    final prefs = await SharedPreferences.getInstance();
    final id = clientId.trim();
    if (id.isEmpty) {
      await prefs.remove(_kClientIdOverride);
    } else {
      await prefs.setString(_kClientIdOverride, id);
    }
    // A different app id invalidates any stored refresh token.
    final storedClient = await _storage.read(key: _kRefreshClient);
    if (storedClient != null && storedClient != id) {
      await signOut();
    }
  }

  // ---------- interactive sign-in ----------

  /// Builds the browser URL and remembers the PKCE verifier for the later
  /// code exchange. Exposed so the UI can offer a manual paste fallback.
  Future<({Uri url, String verifier, String state})> buildAuthorizeRequest() async {
    final clientId = await effectiveClientId();
    if (clientId.isEmpty) {
      throw const GraphAuthException(
          'No Microsoft client ID yet — add one in the setup step first.');
    }
    final verifier = _randomString(64);
    final challenge = base64Url
        .encode(sha256.convert(ascii.encode(verifier)).bytes)
        .replaceAll('=', '');
    final state = _randomString(24);
    _lastVerifier = verifier;
    final url = Uri.https(kGraphAuthorityHost,
        '/$kGraphTenantId/oauth2/v2.0/authorize', {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': kGraphRedirectUri,
      'response_mode': 'query',
      'scope': kGraphScopes.join(' '),
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'state': state,
      'prompt': 'select_account',
    });
    return (url: url, verifier: verifier, state: state);
  }

  /// Opens the system browser and waits for the `whenrufree://auth` redirect.
  /// Returns the authorization code. Throws on cancel/timeout/error.
  Future<String> signInInteractive({Duration timeout = const Duration(minutes: 5)}) async {
    final req = await buildAuthorizeRequest();
    final appLinks = AppLinks();
    final completer = Completer<String>();
    late final StreamSubscription sub;
    sub = appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme != Uri.parse(kGraphRedirectUri).scheme) return;
      if (uri.queryParameters['state'] != req.state) {
        if (!completer.isCompleted) {
          completer.completeError(const GraphAuthException(
              'Sign-in response did not match this request. Try again.'));
        }
        return;
      }
      final err = uri.queryParameters['error'];
      if (err != null) {
        if (!completer.isCompleted) {
          completer.completeError(GraphAuthException(
              uri.queryParameters['error_description'] ?? 'Sign-in failed ($err).'));
        }
        return;
      }
      final code = uri.queryParameters['code'];
      if (code != null && code.isNotEmpty && !completer.isCompleted) {
        completer.complete(code);
      }
    }, onError: (Object e) {
      if (!completer.isCompleted) completer.completeError(e);
    });

    final launched = await launchUrl(req.url,
        mode: LaunchMode.externalApplication);
    if (!launched) {
      await sub.cancel();
      throw const GraphAuthException(
          'Could not open the browser. Paste the sign-in link manually instead.');
    }
    try {
      return await completer.future.timeout(timeout, onTimeout: () {
        throw const GraphAuthException(
            'Sign-in timed out. If the browser did not return to the app, use “paste redirect URL” instead.');
      });
    } finally {
      await sub.cancel();
    }
  }

  /// Exchanges an authorization [code] for tokens. Stores ONLY the refresh
  /// token; keeps the access token in memory.
  Future<void> exchangeCode(
      {required String code, String? verifier}) async {
    final clientId = await effectiveClientId();
    final v = verifier ?? _lastVerifier;
    if (v == null || v.isEmpty) {
      throw const GraphAuthException(
          'Missing sign-in verifier — restart the connect step.');
    }
    final res = await http.post(
      Uri.https(kGraphAuthorityHost, '/$kGraphTenantId/oauth2/v2.0/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': kGraphRedirectUri,
        'code_verifier': v,
      },
    );
    await _storeTokenResponse(res, clientId);
    _lastVerifier = null;
  }

  /// Extracts `code` from a pasted redirect URL (Windows/Linux fallback).
  String parseCodeFromRedirectUrl(String raw) {
    final text = raw.trim();
    if (text.isEmpty) throw const GraphAuthException('Paste the redirect URL first.');
    final uri = Uri.tryParse(text);
    final code = uri?.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw const GraphAuthException(
          'No code found in that URL — copy the full address-bar URL after signing in.');
    }
    final err = uri?.queryParameters['error'];
    if (err != null) {
      throw GraphAuthException('Microsoft refused sign-in ($err).');
    }
    return code;
  }

  // ---------- tokens ----------

  Future<bool> isSignedIn() async {
    try {
      return (await _storage.read(key: _kRefresh))?.isNotEmpty ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Valid access token, refreshing silently via the stored refresh token.
  Future<String> getValidAccessToken() async {
    if (_accessToken != null &&
        _accessExpiresAt != null &&
        DateTime.now().isBefore(
            _accessExpiresAt!.subtract(const Duration(seconds: 90)))) {
      return _accessToken!;
    }
    final refresh = await _storage.read(key: _kRefresh);
    if (refresh == null || refresh.isEmpty) {
      throw const GraphAuthException('Not connected — sign in with Microsoft first.');
    }
    final clientId = await effectiveClientId();
    final res = await http.post(
      Uri.https(kGraphAuthorityHost, '/$kGraphTenantId/oauth2/v2.0/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'grant_type': 'refresh_token',
        'refresh_token': refresh,
        'scope': kGraphScopes.join(' '),
      },
    );
    await _storeTokenResponse(res, clientId, refreshFallback: refresh);
    return _accessToken!;
  }

  Future<void> _storeTokenResponse(http.Response res, String clientId,
      {String? refreshFallback}) async {
    if (res.statusCode != 200) {
      String detail = 'Token request failed (${res.statusCode}).';
      try {
        final body = jsonDecode(res.body) as Map;
        final desc = body['error_description'] as String?;
        if (desc != null && desc.isNotEmpty) detail = _shorten(desc);
      } catch (_) {}
      throw GraphAuthException(detail);
    }
    final body = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    final access = body['access_token'] as String?;
    final refresh = (body['refresh_token'] as String?) ?? refreshFallback;
    final expiresIn = (body['expires_in'] as num?)?.toInt() ?? 3600;
    if (access == null || access.isEmpty) {
      throw const GraphAuthException('Microsoft did not return a token.');
    }
    _accessToken = access;
    _accessExpiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    try {
      if (refresh != null && refresh.isNotEmpty) {
        await _storage.write(key: _kRefresh, value: refresh);
        await _storage.write(key: _kRefreshClient, value: clientId);
      }
    } catch (e) {
      debugPrint('[graph] secure storage write failed: $e');
    }
  }

  Future<void> signOut() async {
    _accessToken = null;
    _accessExpiresAt = null;
    _lastVerifier = null;
    try {
      await _storage.delete(key: _kRefresh);
      await _storage.delete(key: _kRefreshClient);
    } catch (_) {}
  }

  String _randomString(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final r = Random.secure();
    return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
  }

  String _shorten(String s) =>
      s.length > 220 ? '${s.substring(0, 220)}…' : s;
}
