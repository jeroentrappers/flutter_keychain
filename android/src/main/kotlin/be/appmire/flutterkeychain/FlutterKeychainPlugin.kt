package be.appmire.flutterkeychain

import android.annotation.SuppressLint
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.math.BigInteger
import java.nio.charset.Charset
import java.security.*
import java.security.spec.AlgorithmParameterSpec
import java.util.*
import javax.crypto.BadPaddingException
import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec
import javax.security.auth.x500.X500Principal

interface KeyWrapper {
    @Throws(Exception::class)
    fun wrap(key: Key): ByteArray

    @Throws(Exception::class)
    fun unwrap(wrappedKey: ByteArray, algorithm: String): Key
}

class RsaKeyStoreKeyWrapper(context: Context) : KeyWrapper {

    private val keyAlias: String = context.packageName + ".FlutterKeychain"
    private val context: Context = context
    private val TYPE_RSA = "RSA"
    private val KEYSTORE_PROVIDER_ANDROID = "AndroidKeyStore"

    init {
        createRSAKeysIfNeeded()
    }

    @Throws(Exception::class)
    override fun wrap(key: Key): ByteArray {
        val publicKey = getKeyStore().getCertificate(keyAlias)?.publicKey
        val cipher = getRSACipher()
        cipher.init(Cipher.WRAP_MODE, publicKey)
        return cipher.wrap(key)
    }

    @Throws(Exception::class)
    override fun unwrap(wrappedKey: ByteArray, algorithm: String): Key {
        val privateKey = getKeyStore().getKey(keyAlias, null)
        val cipher = getRSACipher()
        cipher.init(Cipher.UNWRAP_MODE, privateKey)
        return cipher.unwrap(wrappedKey, algorithm, Cipher.SECRET_KEY)
    }

    @Throws(Exception::class)
    fun encrypt(input: ByteArray): ByteArray {
        val publicKey = getKeyStore().getCertificate(keyAlias).publicKey
        val cipher = getRSACipher()
        cipher.init(Cipher.ENCRYPT_MODE, publicKey)
        return cipher.doFinal(input)
    }

    @Throws(Exception::class)
    fun decrypt(input: ByteArray): ByteArray {
        val privateKey = getKeyStore().getKey(keyAlias, null)
        val cipher = getRSACipher()
        cipher.init(Cipher.DECRYPT_MODE, privateKey)
        return cipher.doFinal(input)
    }

    @Throws(Exception::class)
    private fun getKeyStore(): KeyStore {
        val ks = KeyStore.getInstance(KEYSTORE_PROVIDER_ANDROID)
        ks.load(null)
        return ks
    }

    @Throws(Exception::class)
    private fun getRSACipher(): Cipher {
        return if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            Cipher.getInstance("RSA/ECB/PKCS1Padding", "AndroidOpenSSL")
        } else {
            Cipher.getInstance("RSA/ECB/PKCS1Padding", "AndroidKeyStoreBCWorkaround")
        }
    }

    @Throws(Exception::class)
    private fun createRSAKeysIfNeeded() {
        val ks = KeyStore.getInstance(KEYSTORE_PROVIDER_ANDROID)
        ks.load(null)

        // Retry loop works around intermittent KeyStore failures on some devices.
        // See: https://stackoverflow.com/questions/36652675
        var privateKey: PrivateKey? = null
        var publicKey: PublicKey? = null
        for (i in 1..5) {
            try {
                privateKey = ks.getKey(keyAlias, null) as PrivateKey
                publicKey = ks.getCertificate(keyAlias).publicKey
                break
            } catch (ignored: Exception) {
            }
        }

        if (privateKey == null || publicKey == null) {
            createKeys()
            try {
                privateKey = ks.getKey(keyAlias, null) as PrivateKey
                publicKey = ks.getCertificate(keyAlias).publicKey
            } catch (ignored: Exception) {
                ks.deleteEntry(keyAlias)
            }
            if (privateKey == null || publicKey == null) {
                createKeys()
            }
        }
    }

    @SuppressLint("NewApi")
    @Throws(Exception::class)
    private fun createKeys() {
        val start = Calendar.getInstance()
        val end = Calendar.getInstance()
        end.add(Calendar.YEAR, 25)

        val kpGenerator = KeyPairGenerator.getInstance(TYPE_RSA, KEYSTORE_PROVIDER_ANDROID)

        val spec: AlgorithmParameterSpec = if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            @Suppress("DEPRECATION")
            android.security.KeyPairGeneratorSpec.Builder(context)
                .setAlias(keyAlias)
                .setSubject(X500Principal("CN=$keyAlias"))
                .setSerialNumber(BigInteger.valueOf(1))
                .setStartDate(start.time)
                .setEndDate(end.time)
                .build()
        } else {
            KeyGenParameterSpec.Builder(
                keyAlias,
                KeyProperties.PURPOSE_DECRYPT or KeyProperties.PURPOSE_ENCRYPT
            )
                .setCertificateSubject(X500Principal("CN=$keyAlias"))
                .setDigests(KeyProperties.DIGEST_SHA256)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_PKCS1)
                .setUserAuthenticationRequired(false)
                .setCertificateSerialNumber(BigInteger.valueOf(1))
                .setCertificateNotBefore(start.time)
                .setCertificateNotAfter(end.time)
                .build()
        }
        kpGenerator.initialize(spec)
        kpGenerator.generateKeyPair()
    }
}

interface StringEncryptor {
    @Throws(Exception::class)
    fun encrypt(input: String?): String?

    fun decrypt(input: String?): String?
}

class AesStringEncryptor @Throws(Exception::class) constructor(
    preferences: SharedPreferences,
    keyWrapper: KeyWrapper
) : StringEncryptor {

    private val ivSize = 16
    private val keySize = 16
    private val KEY_ALGORITHM = "AES"
    private val WRAPPED_AES_KEY_ITEM = "W0n5hlJtrAH0K8mIreDGxtG"
    private val charset: Charset = Charset.forName("UTF-8")
    private val secureRandom: SecureRandom = SecureRandom()

    private var secretKey: Key
    private val cipher: Cipher

    init {
        val wrappedAesKey = preferences.getString(WRAPPED_AES_KEY_ITEM, null)
        secretKey = if (wrappedAesKey == null) {
            createKey(preferences, keyWrapper)
        } else {
            val encrypted = Base64.decode(wrappedAesKey, Base64.DEFAULT)
            try {
                keyWrapper.unwrap(encrypted, KEY_ALGORITHM)
            } catch (ignored: Exception) {
                createKey(preferences, keyWrapper)
            }
        }
        cipher = Cipher.getInstance("AES/CBC/PKCS7Padding")
    }

    fun createKey(preferences: SharedPreferences, keyWrapper: KeyWrapper): Key {
        val key = ByteArray(keySize)
        secureRandom.nextBytes(key)
        val secretKey = SecretKeySpec(key, KEY_ALGORITHM)
        preferences
            .edit()
            .putString(
                WRAPPED_AES_KEY_ITEM,
                Base64.encodeToString(keyWrapper.wrap(secretKey), Base64.DEFAULT)
            )
            .commit()
        return secretKey
    }

    // input: UTF-8 cleartext string
    // output: Base64 encoded encrypted string (IV prepended)
    @Throws(Exception::class)
    override fun encrypt(input: String?): String? {
        if (null == input) return null

        val iv = ByteArray(ivSize)
        secureRandom.nextBytes(iv)
        val ivParameterSpec = IvParameterSpec(iv)

        cipher.init(Cipher.ENCRYPT_MODE, secretKey, ivParameterSpec)

        val payload = cipher.doFinal(input.toByteArray(charset))
        val combined = ByteArray(iv.size + payload.size)
        System.arraycopy(iv, 0, combined, 0, iv.size)
        System.arraycopy(payload, 0, combined, iv.size, payload.size)

        return Base64.encodeToString(combined, Base64.DEFAULT)
    }

    // input: Base64 encoded encrypted string
    // output: UTF-8 cleartext string, or null on decryption failure
    override fun decrypt(input: String?): String? {
        if (null == input) return null

        return try {
            val inputBytes = Base64.decode(input, 0)

            val iv = ByteArray(ivSize)
            System.arraycopy(inputBytes, 0, iv, 0, iv.size)
            val ivParameterSpec = IvParameterSpec(iv)

            val payloadSize = inputBytes.size - ivSize
            val payload = ByteArray(payloadSize)
            System.arraycopy(inputBytes, iv.size, payload, 0, payloadSize)

            cipher.init(Cipher.DECRYPT_MODE, secretKey, ivParameterSpec)
            val outputBytes = cipher.doFinal(payload)
            String(outputBytes, charset)
        } catch (e: BadPaddingException) {
            Log.w(TAG, "Decryption failed — key may be out of sync with stored data. Returning null.", e)
            null
        } catch (e: InvalidKeyException) {
            Log.w(TAG, "Decryption failed — invalid key. Returning null.", e)
            null
        } catch (e: Exception) {
            Log.w(TAG, "Decryption failed: ${e.message}. Returning null.", e)
            null
        }
    }

    private companion object {
        const val TAG = "flutter_keychain"
    }
}

class FlutterKeychainPlugin : FlutterPlugin, MethodCallHandler {

    private var channel: MethodChannel? = null

    // Coroutine scope tied to the lifecycle of this plugin instance.
    // SupervisorJob means one failed child doesn't cancel the rest.
    private val pluginScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    // Becomes non-null after background init completes.
    // Only read/written on the Main dispatcher.
    private var encryptor: StringEncryptor? = null

    // Calls that arrive before the encryptor is ready are queued here and
    // replayed once init finishes. Accessed on Main only.
    private val pendingCalls = ArrayDeque<Pair<MethodCall, Result>>()

    private var preferences: SharedPreferences? = null

    companion object {
        private const val TAG = "flutter_keychain"
        private const val CHANNEL_NAME = "plugin.appmire.be/flutter_keychain"
        private const val WRAPPED_AES_KEY_ITEM = "W0n5hlJtrAH0K8mIreDGxtG"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val context = binding.applicationContext
        preferences = context.getSharedPreferences("FlutterKeychain", Context.MODE_PRIVATE)

        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel!!.setMethodCallHandler(this)

        // Initialise crypto on IO — never block the main thread.
        pluginScope.launch {
            val result = withContext(Dispatchers.IO) {
                runCatching {
                    AesStringEncryptor(
                        preferences = preferences!!,
                        keyWrapper = RsaKeyStoreKeyWrapper(context)
                    ) as StringEncryptor
                }.getOrElse { e ->
                    Log.e(TAG, "Failed to initialise crypto engine", e)
                    null
                }
            }

            // Back on Main — safe to mutate state and flush queued calls.
            encryptor = result
            val pending = pendingCalls.toList()
            pendingCalls.clear()
            for ((call, res) in pending) {
                dispatchCall(call, res)
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        pluginScope.cancel()
        encryptor = null
        pendingCalls.clear()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (encryptor == null) {
            // Crypto engine not ready yet — queue until init completes.
            pendingCalls.addLast(call to result)
            return
        }
        dispatchCall(call, result)
    }

    private fun dispatchCall(call: MethodCall, result: Result) {
        val enc = encryptor
        if (enc == null) {
            result.error(TAG, "Crypto engine not available", null)
            return
        }
        val prefs = preferences!!

        pluginScope.launch {
            try {
                when (call.method) {
                    "get" -> {
                        val key = call.argument<String>("key")
                        val value = withContext(Dispatchers.IO) {
                            enc.decrypt(prefs.getString(key, null))
                        }
                        result.success(value)
                    }
                    "put" -> {
                        val key = call.argument<String>("key")
                        val value = call.argument<String>("value")
                        withContext(Dispatchers.IO) {
                            prefs.edit().putString(key, enc.encrypt(value)).commit()
                        }
                        result.success(null)
                    }
                    "remove" -> {
                        val key = call.argument<String>("key")
                        withContext(Dispatchers.IO) {
                            prefs.edit().remove(key).commit()
                        }
                        result.success(null)
                    }
                    "clear" -> {
                        withContext(Dispatchers.IO) {
                            val savedKey = prefs.getString(WRAPPED_AES_KEY_ITEM, null)
                            prefs.edit().clear().commit()
                            prefs.edit().putString(WRAPPED_AES_KEY_ITEM, savedKey).commit()
                        }
                        result.success(null)
                    }
                    "configure" -> {
                        // Access groups and labels are iOS-only; no-op on Android.
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                Log.e(TAG, e.message ?: e.toString())
                result.error(TAG, e.message, e)
            }
        }
    }
}
