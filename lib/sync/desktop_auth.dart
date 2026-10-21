import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Login Google no PC (Windows): o google_sign_in não tem implementação
/// desktop, então abre o navegador e recebe o código num servidor local
/// (OAuth "loopback"). Um login só serve p/ Drive e Firebase; o refresh
/// token fica salvo p/ entrar sozinho na próxima vez.
class DesktopAuth {
  DesktopAuth._();
  static final instance = DesktopAuth._();

  static bool get ativo => !kIsWeb && Platform.isWindows;

  /// Client OAuth tipo "App para computador" do mesmo projeto Google do
  /// webClientId. Em app instalado o secret não é sigilo (vai no binário).
  static const _id = String.fromEnvironment(
    'ARION_DESKTOP_ID',
    defaultValue: '',
  );
  static const _secret = String.fromEnvironment(
    'ARION_DESKTOP_SECRET',
    defaultValue: '',
  );
  static bool get configurado => _id.isNotEmpty;

  static const _scopes = [
    'openid',
    'email',
    drive.DriveApi.driveAppdataScope,
  ];

  final _clientId = ClientId(_id, _secret.isEmpty ? null : _secret);
  AccessCredentials? _cred;
  String email = '';

  bool get logado => _cred != null;

  Future<File> _arquivo() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/google_desktop.json');
  }

  Future<void> _salva() async {
    final c = _cred;
    if (c == null) return;
    await (await _arquivo()).writeAsString(
      jsonEncode({'cred': c.toJson(), 'email': email}),
    );
  }

  /// Volta a sessão salva (sem abrir navegador). false = precisa entrar.
  Future<bool> silencioso() async {
    if (_cred != null) return true;
    if (!configurado) return false;
    try {
      final f = await _arquivo();
      if (!await f.exists()) return false;
      final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final salvo = AccessCredentials.fromJson(
        (m['cred'] as Map).cast<String, dynamic>(),
      );
      final base = http.Client();
      try {
        _cred = await refreshCredentials(_clientId, salvo, base);
      } finally {
        base.close();
      }
      email = (m['email'] ?? '') as String;
      await _salva();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> entrar() async {
    if (await silencioso()) return true;
    if (!configurado) {
      throw 'Login no PC não configurado (falta o client OAuth desktop)';
    }
    final base = http.Client();
    try {
      _cred = await obtainAccessCredentialsViaUserConsent(
        _clientId,
        _scopes,
        base,
        _abreNavegador,
      );
    } finally {
      base.close();
    }
    email = _emailDoIdToken(_cred!.idToken);
    await _salva();
    return true;
  }

  Future<void> sair() async {
    _cred = null;
    email = '';
    try {
      final f = await _arquivo();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// idToken do último login/renovação (o Firebase exige ele).
  String? get idToken => _cred?.idToken;

  /// Token atual (renova se venceu) p/ o login do Firebase.
  Future<String?> accessToken() async {
    final c = _cred;
    if (c == null) return null;
    if (c.accessToken.hasExpired) {
      final base = http.Client();
      try {
        _cred = await refreshCredentials(_clientId, c, base);
      } finally {
        base.close();
      }
      await _salva();
    }
    return _cred!.accessToken.data;
  }

  /// Cliente HTTP autenticado p/ o Drive (renova o token sozinho).
  http.Client? client() {
    final c = _cred;
    if (c == null) return null;
    final auto = autoRefreshingClient(_clientId, c, http.Client());
    auto.credentialUpdates.listen((n) {
      _cred = n;
      _salva();
    });
    return auto;
  }

  static void _abreNavegador(String url) {
    // rundll32 não interpreta & da URL (cmd /c start interpretaria)
    Process.run('rundll32', ['url.dll,FileProtocolHandler', url]);
  }

  static String _emailDoIdToken(String? idToken) {
    if (idToken == null) return '';
    try {
      final p = idToken.split('.')[1];
      final m = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(p))));
      return (m['email'] ?? '') as String;
    } catch (_) {
      return '';
    }
  }
}
