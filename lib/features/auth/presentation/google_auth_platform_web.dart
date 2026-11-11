import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../domain/auth_session_controller.dart';
import '../domain/google_authentication_gateway.dart';

@JS('google.accounts.id.initialize')
external void _initialize(JSObject configuration);
@JS('google.accounts.id.renderButton')
external void _renderButton(web.HTMLElement element, JSObject configuration);
@JS('google.accounts.id.disableAutoSelect')
external void _disableAutoSelect();

extension type _Credential(JSObject _) implements JSObject {
  external JSString? get credential;
  external JSString? get state;
}

/// GIS is loaded once; failed loads can be retried explicitly.
Future<void>? _sdk;
Object? _owner;
Future<void> _loadSdk() => _sdk ??= _loadSdkOnce();

/// Injectable SDK boundary for browser-only failure and callback tests.
abstract interface class WebGoogleServices {
  Future<void> load();
  void initialize(JSObject configuration);
  void renderButton(web.HTMLElement element, JSObject configuration);
}

class _BrowserGoogleServices implements WebGoogleServices {
  const _BrowserGoogleServices();
  @override
  Future<void> load() => _loadSdk();
  @override
  void initialize(JSObject configuration) => _initialize(configuration);
  @override
  void renderButton(web.HTMLElement element, JSObject configuration) =>
      _renderButton(element, configuration);
}

Future<void> _loadSdkOnce() async {
  final script = web.HTMLScriptElement()
    ..src = 'https://accounts.google.com/gsi/client'
    ..async = true
    ..defer = true;
  final loaded = Completer<void>();
  script.onload = ((web.Event _) {
    if (!loaded.isCompleted) loaded.complete();
  }).toJS;
  script.onerror = ((web.Event _) {
    if (!loaded.isCompleted) {
      loaded.completeError(StateError('GIS load failed'));
    }
  }).toJS;
  web.document.head!.appendChild(script);
  try {
    await loaded.future.timeout(const Duration(seconds: 20));
  } catch (_) {
    script.remove();
    _sdk = null;
    rethrow;
  } finally {
    script.onload = null;
    script.onerror = null;
  }
}

class _WebGoogleGateway implements GoogleAuthenticationGateway {
  @override
  Future<GoogleAuthenticationProof> authenticate({
    required String serverClientId,
    required String nonce,
  }) async => throw const GoogleAuthenticationException(
    GoogleAuthenticationFailure.unavailable,
  );

  @override
  Future<void> clearCredentialState() async {
    if (_sdk != null) {
      await _sdk;
      _disableAutoSelect();
    }
  }
}

GoogleAuthenticationGateway createGoogleAuthenticationGateway() =>
    _WebGoogleGateway();

Widget buildWebGoogleButton({
  required AuthSessionController auth,
  required bool remember,
  required ValueChanged<bool> onLocked,
  required VoidCallback onSuccess,
  WebGoogleServices services = const _BrowserGoogleServices(),
}) => _WebGoogleButton(
  auth: auth,
  remember: remember,
  onLocked: onLocked,
  onSuccess: onSuccess,
  services: services,
);

class _WebGoogleButton extends StatefulWidget {
  const _WebGoogleButton({
    required this.auth,
    required this.remember,
    required this.onLocked,
    required this.onSuccess,
    required this.services,
  });
  final AuthSessionController auth;
  final bool remember;
  final ValueChanged<bool> onLocked;
  final VoidCallback onSuccess;
  final WebGoogleServices services;
  @override
  State<_WebGoogleButton> createState() => _WebGoogleButtonState();
}

class _WebGoogleButtonState extends State<_WebGoogleButton> {
  PreparedGoogleLogin? _attempt;
  web.HTMLElement? _element;
  Timer? _expiry;
  Timer? _attachment;
  int _generation = 0;
  bool _preparing = true, _clicked = false, _exchanging = false;
  bool? _remember;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_prepare());
    });
  }

  void _clear({bool deferNotification = false}) {
    ++_generation;
    _expiry?.cancel();
    _expiry = null;
    _attachment?.cancel();
    _attachment = null;
    _element?.textContent = '';
    _element = null;
    final owned = identical(_owner, this);
    if (owned) _owner = null;
    if (owned || _attempt != null) {
      widget.auth.cancelGoogleLogin(
        _attempt,
        deferNotification: deferNotification,
      );
    }
    _attempt = null;
  }

  Future<void> _prepare() async {
    _clear();
    final generation = _generation;
    _owner = this;
    setState(() {
      _preparing = true;
      _clicked = _exchanging = false;
      _remember = null;
      _message = null;
    });
    widget.onLocked(true);
    try {
      // SDK first: a blocked script must not create repeated server challenges.
      await widget.services.load();
      if (!mounted || generation != _generation || !identical(_owner, this)) {
        return;
      }
      final attempt = await widget.auth.prepareGoogleLogin();
      if (!mounted || generation != _generation || !identical(_owner, this)) {
        if (attempt != null) widget.auth.cancelGoogleLogin(attempt);
        return;
      }
      if (attempt == null) {
        _fail('로그인 준비를 완료하지 못했습니다. 다시 시도해 주세요.');
        return;
      }
      _attempt = attempt;
      _expiry = Timer(attempt.expiresAt.difference(DateTime.now().toUtc()), () {
        if (mounted && !_exchanging) {
          _fail('로그인 준비 시간이 지났습니다. 다시 시도해 주세요.');
        }
      });
      setState(() => _preparing = false);
      widget.onLocked(false);
    } catch (_) {
      if (mounted && generation == _generation) {
        if (kDebugMode) {
          debugPrint('[google-auth] stage=web_prepare code=SDK_UNAVAILABLE');
        }
        _fail('Google 로그인을 준비하지 못했습니다. 연결 상태를 확인하고 다시 시도해 주세요.');
      }
    }
  }

  void _fail(String message) {
    _clear();
    setState(() {
      _preparing = _clicked = _exchanging = false;
      _message = message;
    });
    widget.onLocked(false);
  }

  void _render(web.HTMLElement element, double width) {
    final attempt = _attempt;
    if (attempt == null ||
        !widget.auth.isGoogleLoginCurrent(attempt) ||
        !identical(_owner, this)) {
      return;
    }
    _element = element;
    final generation = _generation;
    widget.services.initialize(
      {
            'client_id': widget.auth.serverClientId,
            'nonce': attempt.nonce,
            'auto_select': false,
            'button_auto_select': false,
            'ux_mode': 'popup',
            'callback': ((_Credential response) {
              if (!mounted ||
                  generation != _generation ||
                  !identical(_owner, this) ||
                  _exchanging ||
                  !_clicked ||
                  !widget.auth.isGoogleLoginCurrent(attempt)) {
                return;
              }
              // Button state is correlation only; Backend verifies the token and nonce.
              if (response.state?.toDart != attempt.state) {
                if (kDebugMode) {
                  debugPrint(
                    '[google-auth] stage=web_callback code=STALE_STATE',
                  );
                }
                return;
              }
              final token = response.credential?.toDart;
              if (token == null || token.trim().isEmpty) {
                _fail('Google 인증 결과를 확인하지 못했습니다. 다시 시도해 주세요.');
                return;
              }
              unawaited(_exchange(attempt, GoogleAuthenticationProof(token)));
            }).toJS,
          }.jsify()!
          as JSObject,
    );
    widget.services.renderButton(
      element,
      {
            'theme': 'outline',
            'size': 'large',
            'text': 'continue_with',
            'locale': 'ko',
            'width': width.clamp(200, 400).round(),
            'state': attempt.state,
            'click_listener': (() {
              if (!mounted ||
                  generation != _generation ||
                  _clicked ||
                  !widget.auth.isGoogleLoginCurrent(attempt)) {
                return;
              }
              _remember = widget.remember;
              element.style.pointerEvents = 'none';
              setState(() => _clicked = true);
              widget.onLocked(true);
            }).toJS,
          }.jsify()!
          as JSObject,
    );
    if (kDebugMode) {
      debugPrint(
        '[google-auth] stage=web_button_ready clientIdPresent=true noncePresent=true',
      );
    }
  }

  Future<void> _exchange(
    PreparedGoogleLogin attempt,
    GoogleAuthenticationProof proof,
  ) async {
    _exchanging = true;
    _expiry?.cancel();
    setState(() {});
    final generation = _generation;
    final success = await widget.auth.completeGoogleLogin(
      attempt,
      proof,
      remember: _remember ?? false,
    );
    if (!mounted || generation != _generation) return;
    if (success) {
      _attempt = null;
      _element?.textContent = '';
      widget.onSuccess();
    } else {
      _fail('로그인을 완료하지 못했습니다. 다시 시도해 주세요.');
    }
  }

  @override
  void dispose() {
    _clear(deferNotification: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (_preparing)
        const SizedBox(
          height: 44,
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_message != null)
        Text(_message!)
      else
        LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            height: 44,
            child: HtmlElementView.fromTagName(
              key: ValueKey(_generation),
              tagName: 'div',
              onElementCreated: (element) {
                final generation = _generation;
                final container = element as web.HTMLElement;
                // Platform views are not attached yet in onElementCreated.
                _attachment = Timer.periodic(const Duration(milliseconds: 50), (
                  timer,
                ) {
                  if (!mounted || generation != _generation) {
                    timer.cancel();
                    return;
                  }
                  if (!container.isConnected && timer.tick < 200) return;
                  timer.cancel();
                  try {
                    if (!container.isConnected) {
                      throw StateError('Button not attached');
                    }
                    _render(container, constraints.maxWidth);
                  } catch (_) {
                    _fail('Google 로그인 버튼을 준비하지 못했습니다. 다시 시도해 주세요.');
                  }
                });
              },
            ),
          ),
        ),
      if (_clicked && !_exchanging) const Text('Google 계정 선택을 완료해 주세요.'),
      if (!_preparing && !_exchanging && (_clicked || _message != null))
        TextButton(
          onPressed: _prepare,
          child: Text(_clicked ? '취소하고 다시 시도' : '다시 시도'),
        ),
    ],
  );
}
