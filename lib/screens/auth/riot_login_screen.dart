import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';
import 'package:valorant_thunai/providers/auth_provider.dart';
import 'package:valorant_thunai/services/logger_service.dart';
import 'package:valorant_thunai/services/riot_auth_service.dart';

class RiotLoginScreen extends ConsumerStatefulWidget {
  const RiotLoginScreen({super.key});

  @override
  ConsumerState<RiotLoginScreen> createState() => _RiotLoginScreenState();
}

class _RiotLoginScreenState extends ConsumerState<RiotLoginScreen> {
  static const String _riotLoginUrl =
      'https://auth.riotgames.com/authorize?redirect_uri=https%3A%2F%2Fplayvalorant.com%2Fopt_in&client_id=play-valorant-web-prod&response_type=token%20id_token&scope=account%20openid&nonce=1&display=touch';

  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isClearingData = true;
  bool _hasRedirected = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    try {
      final cookieManager = WebViewCookieManager();
      await cookieManager.clearCookies();
    } catch (e) {
      LoggerService.log(
        "Error clearing cookies/cache: $e",
        tag: 'LoginWebview',
      );
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (progress > 80 && _isLoading) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            }
          },
          onPageStarted: (String url) {
            _handleRedirect(url);
          },
          onUrlChange: (UrlChange change) {
            if (change.url != null) {
              _handleRedirect(change.url!);
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null &&
                uri.host.contains("playvalorant.com") &&
                uri.path.contains("opt_in")) {
              _handleRedirect(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(_riotLoginUrl));

    if (mounted) {
      setState(() {
        _isClearingData = false;
      });
    }
  }

  void _handleRedirect(String urlStr) async {
    if (_hasRedirected) return;
    final url = Uri.tryParse(urlStr);
    if (url == null) return;

    if (url.host.contains("playvalorant.com") && url.path.contains("opt_in")) {
      _hasRedirected = true;

      String logUrl = urlStr;
      if (logUrl.contains('#')) {
        logUrl = '${logUrl.split('#').first}#<REDACTED>';
      }
      LoggerService.log(
        "DETECTED CALLBACK URL in helper: $logUrl",
        tag: 'LoginWebview',
      );

      if (_isProcessing) return;
      setState(() {
        _isProcessing = true;
      });

      String fragment = url.fragment;
      if (fragment.isEmpty) {
        if (urlStr.contains('#')) {
          fragment = urlStr.split('#').last;
        }
      }

      if (fragment.isNotEmpty) {
        LoggerService.log("FRAGMENT FOUND", tag: 'LoginWebview');
        final Map<String, String> fragments = Uri.splitQueryString(fragment);
        final String? accessToken = fragments['access_token'];
        final String? idToken = fragments['id_token'];

        if (accessToken != null && idToken != null) {
          LoggerService.log("TOKENS CAPTURED", tag: 'LoginWebview');

          String? cookieStr;
          try {
            final cookieManager = WebViewCookieManager();

            final callbackCookies = await cookieManager.getCookies(
              domain: Uri.parse("https://playvalorant.com"),
            );
            final authCookies = await cookieManager.getCookies(
              domain: Uri.parse("https://auth.riotgames.com"),
            );

            LoggerService.log(
              'callbackCookieCount=${callbackCookies.length}, authCookieCount=${authCookies.length}',
              tag: 'LoginCookies',
            );

            final Map<String, WebViewCookie> cookieMap = {};

            for (var c in authCookies) {
              cookieMap[c.name] = c;
            }
            for (var c in callbackCookies) {
              cookieMap[c.name] = c;
            }

            cookieStr = RiotAuthService.serializeCookies(
              cookieMap.values.toList(),
            );

            LoggerService.log(
              "COOKIES CAPTURED (Count: ${cookieMap.length})",
              tag: 'LoginWebview',
            );
          } catch (e) {
            LoggerService.log(
              "FAILED TO CAPTURE COOKIES: $e",
              tag: 'LoginWebview',
            );
          }

          try {
            await ref
                .read(authProvider.notifier)
                .loginWithTokens(accessToken, idToken, cookies: cookieStr);

            LoggerService.log("LOGIN WITH TOKENS COMPLETED", tag: 'RiotAuth');

            if (mounted) {
              final l10n = AppLocalizations.of(context)!;
              final authState = ref.read(authProvider);
              if (authState.user != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.loginSuccessfulSnackbar)),
                );
                Navigator.pop(context);
              } else {
                LoggerService.log(
                  "Login error: ${authState.error}",
                  tag: 'RiotAuth',
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      l10n.loginFailedSnackbar(
                        authState.error ?? l10n.unknownItem,
                      ),
                    ),
                  ),
                );
                setState(() {
                  _isProcessing = false;
                  _hasRedirected = false;
                });
              }
            }
          } catch (e) {
            LoggerService.log("Exception during login: $e", tag: 'RiotAuth');
            if (mounted) {
              setState(() {
                _isProcessing = false;
                _hasRedirected = false;
              });
            }
          }
        } else {
          LoggerService.log("Tokens missing in fragment", tag: 'LoginWebview');
          setState(() {
            _isProcessing = false;
            _hasRedirected = false;
          });
        }
      } else {
        LoggerService.log("URL Fragment empty", tag: 'LoginWebview');
        setState(() {
          _isProcessing = false;
          _hasRedirected = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_isClearingData) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.riotLoginTitle)),
        body: const Center(child: FunnyLoadingView(color: Colors.redAccent)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.riotLoginTitle)),
      body: Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: _controller)),
          if (_isLoading)
            const Center(child: FunnyLoadingView(color: Colors.redAccent)),
          if (_isProcessing)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FunnyLoadingView(),
                    const SizedBox(height: 24),
                    Text(
                      l10n.authenticatingWithRiot,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.fetchingYourAccountDetails,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
