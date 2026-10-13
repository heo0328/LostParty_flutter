package kr.co.heowork0921.lostparty

import android.app.Activity
import android.os.CancellationSignal
import androidx.core.content.ContextCompat
import androidx.credentials.ClearCredentialStateRequest
import androidx.credentials.CredentialManager
import androidx.credentials.CredentialManagerCallback
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.exceptions.ClearCredentialException
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.GetCredentialProviderConfigurationException
import androidx.credentials.exceptions.GetCredentialUnsupportedException
import androidx.credentials.exceptions.NoCredentialException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Acquires evidence only. The Backend owns proof validation and app sessions. */
class GoogleAuthenticationBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "lostparty/google_auth")
    private val manager = CredentialManager.create(activity)
    private val executor = ContextCompat.getMainExecutor(activity)
    private var pending: MethodChannel.Result? = null
    private var cancellation: CancellationSignal? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "authenticate" && call.method != "clearCredentialState") {
            result.notImplemented()
            return
        }
        if (pending != null) {
            result.error("BUSY", "Google authentication is already in progress.", null)
            return
        }
        if (activity.isFinishing || activity.isDestroyed) {
            result.error("UNAVAILABLE", "Google authentication UI is unavailable.", null)
            return
        }
        val serverClientId = call.argument<String>("serverClientId")
        val nonce = call.argument<String>("nonce")
        if (call.method == "authenticate" && (serverClientId.isNullOrBlank() || nonce.isNullOrBlank())) {
            result.error("INVALID_REQUEST", "Client ID and server nonce are required.", null)
            return
        }
        pending = result
        val signal = CancellationSignal()
        cancellation = signal
        try {
            if (call.method == "clearCredentialState") {
                clearCredentialState(result, signal)
            } else {
                authenticate(serverClientId!!, nonce!!, result, signal)
            }
        } catch (_: Exception) {
            complete(result) { it.error("FAILED", "Google authentication could not start.", null) }
        }
    }

    private fun authenticate(
        clientId: String,
        nonce: String,
        result: MethodChannel.Result,
        signal: CancellationSignal,
    ) {
        val option = GetSignInWithGoogleOption.Builder(clientId).setNonce(nonce).build()
        val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
        manager.getCredentialAsync(activity, request, signal, executor,
            object : CredentialManagerCallback<GetCredentialResponse, GetCredentialException> {
                override fun onResult(response: GetCredentialResponse) {
                    val credential = response.credential
                    if (credential !is CustomCredential ||
                        credential.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
                        complete(result) { it.error("INVALID_RESPONSE", "Unexpected Google credential.", null) }
                        return
                    }
                    try {
                        val token = GoogleIdTokenCredential.createFrom(credential.data).idToken
                        if (token.isBlank()) {
                            complete(result) { it.error("INVALID_RESPONSE", "Google proof is empty.", null) }
                        } else {
                            complete(result) { it.success(token) }
                        }
                    } catch (_: Exception) {
                        complete(result) { it.error("INVALID_RESPONSE", "Invalid Google credential.", null) }
                    }
                }

                override fun onError(error: GetCredentialException) {
                    val code = when (error) {
                        is GetCredentialCancellationException -> "CANCELLED"
                        is GetCredentialProviderConfigurationException,
                        is GetCredentialUnsupportedException,
                        is NoCredentialException -> "UNAVAILABLE"
                        else -> "FAILED"
                    }
                    complete(result) { it.error(code, "Google authentication did not complete.", null) }
                }
            })
    }

    private fun clearCredentialState(result: MethodChannel.Result, signal: CancellationSignal) {
        manager.clearCredentialStateAsync(ClearCredentialStateRequest(), signal, executor,
            object : CredentialManagerCallback<Void?, ClearCredentialException> {
                override fun onResult(response: Void?) {
                    complete(result) { it.success(null) }
                }

                override fun onError(error: ClearCredentialException) {
                    complete(result) { it.error("FAILED", "Could not clear Google credential state.", null) }
                }
            })
    }

    private fun complete(result: MethodChannel.Result, deliver: (MethodChannel.Result) -> Unit) {
        if (pending !== result) return
        pending = null
        cancellation = null
        deliver(result)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        val result = pending
        val signal = cancellation
        pending = null
        cancellation = null
        signal?.cancel()
        result?.error("CANCELLED", "Google authentication UI was detached.", null)
    }
}
