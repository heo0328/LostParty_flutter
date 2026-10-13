package kr.co.heowork0921.lostparty

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var googleAuthenticationBridge: GoogleAuthenticationBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        googleAuthenticationBridge = GoogleAuthenticationBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        googleAuthenticationBridge?.dispose()
        googleAuthenticationBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
