import 'package:flutter/material.dart';

typedef AppInitializer = Future<void> Function();

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({
    required this.initialize,
    required this.appBuilder,
    super.key,
  });

  final AppInitializer initialize;
  final WidgetBuilder appBuilder;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  var _attempt = 0;
  late Future<void> _initialization;

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
    return FutureBuilder<void>(
      key: ValueKey(_attempt),
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootstrapFrame(
            child: CircularProgressIndicator(
              key: Key('firebase-bootstrap-loading'),
            ),
          );
        }
        if (snapshot.hasError) {
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
        return widget.appBuilder(context);
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
