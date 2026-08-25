import 'package:flutter/material.dart';

typedef AppInitializer<T> = Future<T> Function();

typedef AppBuilder<T> = Widget Function(BuildContext context, T services);

class AppBootstrap<T extends Object> extends StatefulWidget {
  const AppBootstrap({
    required this.initialize,
    required this.appBuilder,
    super.key,
  });

  final AppInitializer<T> initialize;
  final AppBuilder<T> appBuilder;

  @override
  State<AppBootstrap<T>> createState() => _AppBootstrapState<T>();
}

class _AppBootstrapState<T extends Object> extends State<AppBootstrap<T>> {
  var _attempt = 0;
  late Future<T> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = widget.initialize();
  }

  void _retry() {
    setState(() {
      _attempt += 1;
      _initialization = widget.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      key: ValueKey(_attempt),
      future: _initialization,
      builder: (context, snapshot) {
        final services = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootstrapFrame(
            child: CircularProgressIndicator(
              key: Key('firebase-bootstrap-loading'),
            ),
          );
        }
        if (snapshot.hasError || services == null) {
          return _BootstrapFrame(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 48),
                const SizedBox(height: 16),
                const Text(
                  '앱 연결을 준비하지 못했습니다.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  '네트워크 상태를 확인한 뒤 다시 시도해 주세요.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('firebase-bootstrap-retry'),
                  onPressed: _retry,
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          );
        }
        return widget.appBuilder(context, services);
      },
    );
  }
}

class _BootstrapFrame extends StatelessWidget {
  const _BootstrapFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LOSTPARTY',
      home: Scaffold(body: Center(child: child)),
    );
  }
}
