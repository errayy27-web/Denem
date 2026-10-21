package com.ssoil.stokkontrol

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONObject

/** TEST SERVICE. Does not claim reliable automatic parsing of Flutter semantics. */
class PopisAccessibilityService: AccessibilityService() {
 private var lastText=""
 override fun onAccessibilityEvent(event: AccessibilityEvent?) {
  val pkg=event?.packageName?.toString() ?: return
  if(pkg==packageName || pkg.startsWith("com.android") || pkg.startsWith("com.google"))return
  val parts=mutableListOf<String>()
  fun collect(node: AccessibilityNodeInfo?,depth:Int=0){
   if(node==null || depth>20 || parts.size>150)return
   node.text?.toString()?.takeIf{it.isNotBlank()}?.let{parts.add(it)}
   for(i in 0 until node.childCount)collect(node.getChild(i),depth+1)
  }
  collect(rootInActiveWindow)
  val snapshot=parts.joinToString(" | ")
  if(snapshot.isBlank() || snapshot==lastText)return
  lastText=snapshot
  // Store raw text for diagnostics. Field extraction must be validated on-device.
  getSharedPreferences("popis_bridge",MODE_PRIVATE).edit()
   .putString("raw_text",snapshot).putString("source_package",pkg).apply()
 }
 override fun onInterrupt() {}
}
