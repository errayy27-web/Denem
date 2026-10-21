package com.ssoil.stokkontrol

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
 override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
  super.configureFlutterEngine(flutterEngine)
  MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"ssoil.popis/bridge").setMethodCallHandler { call,result ->
   when(call.method) {
    "accessibilitySettings" -> {startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS));result.success(null)}
    "readPopis" -> result.success(getSharedPreferences("popis_bridge",MODE_PRIVATE).getString("raw_text",null))
    "returnPopis" -> {
      val pkg=getSharedPreferences("popis_bridge",MODE_PRIVATE).getString("source_package",null)
      val intent=if(pkg!=null)packageManager.getLaunchIntentForPackage(pkg) else null
      if(intent!=null){startActivity(intent);result.success(null)} else result.error("NO_APP","Popis paketi henüz tespit edilmedi",null)
    }
    else -> result.notImplemented()
   }
  }
 }
}
