package be.appmire.flutter_keychain

import android.content.Context
import android.content.SharedPreferences

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** FlutterKeychainPlugin */
class FlutterKeychainPlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel

  /// The plugin binding that is used to get the ApplicationContext.
  private var pluginBinding: FlutterPlugin.FlutterPluginBinding? = null

  companion object {
    private const val WRAPPED_AES_KEY_ITEM = "W0n5hlJtrAH0K8mIreDGxtG"
  }

  /// Get the shared preferences for the given name.
  ///
  /// Defaults to "FlutterKeychain" if the name is null.
  private fun getPreferences(preferencesName: String?): SharedPreferences? {
    return pluginBinding?.applicationContext?.getSharedPreferences(
      preferencesName ?: "FlutterKeychain",
      Context.MODE_PRIVATE,
      )
  }

  private fun getEncryptor(preferences: SharedPreferences) : StringEncryptor? {
    val context: Context = pluginBinding?.applicationContext ?: return null

    val keyWrapper = RsaKeyStoreKeyWrapper(context)

    return AesStringEncryptor(preferences, keyWrapper, WRAPPED_AES_KEY_ITEM)
  }

  private fun MethodCall.key(): String? {
    return this.argument("key")
  }

  private fun MethodCall.keychainName(): String? {
    return this.argument("keyChainName")
  }

  private fun MethodCall.value(): String? {
    return this.argument("value")
  }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    pluginBinding = flutterPluginBinding
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "plugin.appmire.be/flutter_keychain")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when(call.method) {
      "clear" -> clearKeychain(call, result)
      "get" -> getValue(call, result)
      "put" -> putValue(call, result)
      "remove" -> removeValue(call, result)
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    pluginBinding = null
    channel.setMethodCallHandler(null)
  }

  private fun clearKeychain(call: MethodCall, result: Result) {
    try {
      val preferences = getPreferences(call.keychainName())

      preferences?.let {
        val savedValue: String? = it.getString(WRAPPED_AES_KEY_ITEM, null)
        it.edit().clear().apply()
        it.edit().putString(WRAPPED_AES_KEY_ITEM, savedValue).commit()
      }

      result.success(null)
    } catch (exception: Exception) {
      result.error(
        "KEYCHAIN_CLEAR_ERROR",
        exception.localizedMessage,
        exception.stackTrace.toString())
    }
  }

  private fun getValue(call: MethodCall, result: Result) {
    try {
      val preferences = getPreferences(call.keychainName())

      if (preferences == null) {
        result.success(null)

        return
      }

      val encryptedValue: String? = preferences.getString(call.key(), null)
      val encryptor = getEncryptor(preferences)

      if (encryptor == null) {
        result.success(null)

        return
      }

      val value = encryptor.decrypt(encryptedValue)

      result.success(value)
    } catch (exception: Exception) {
      result.success(null)
    }
  }

  private fun putValue(call: MethodCall, result: Result) {
    try {
      val preferences = getPreferences(call.keychainName())

      if (preferences == null) {
        result.success(null)

        return
      }

      val encryptor = getEncryptor(preferences)

      if (encryptor == null) {
        result.success(null)

        return
      }

      val value = encryptor.encrypt(call.value())
      preferences.edit().putString(call.key(), value).apply()

      result.success(null)
    } catch (exception: Exception) {
      result.error(
        "KEYCHAIN_PUT_VALUE_ERROR",
        exception.localizedMessage,
        exception.stackTrace.toString())
    }
  }

  private fun removeValue(call: MethodCall, result: Result) {
    try {
      val preferences = getPreferences(call.keychainName())

      preferences?.edit()?.remove(call.key())?.apply()

      result.success(null)
    } catch (exception: Exception) {
      result.error(
        "KEYCHAIN_REMOVE_VALUE_ERROR",
        exception.localizedMessage,
        exception.stackTrace.toString())
    }
  }
}
