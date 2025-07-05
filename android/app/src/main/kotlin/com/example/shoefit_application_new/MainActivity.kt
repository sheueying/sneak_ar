package com.example.shoefit_application_new

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import org.json.JSONObject

class MainActivity: FlutterActivity() {
    private val CHANNEL = "deepar_channel"
    private var deepARView: DeepARView? = null
    private var isARActive = false
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    val licenseKey = call.argument<String>("licenseKey")
                    initializeDeepAR(licenseKey, result)
                }
                "startARSession" -> {
                    startARSession(result)
                }
                "stopARSession" -> {
                    stopARSession(result)
                }
                "switchEffect" -> {
                    val effectPath = call.argument<String>("effectPath")
                    switchEffect(effectPath, result)
                }
                "takeScreenshot" -> {
                    takeScreenshot(result)
                }
                "startRecording" -> {
                    startRecording(result)
                }
                "stopRecording" -> {
                    stopRecording(result)
                }
                "isAvailable" -> {
                    result.success(true)
                }
                "getAvailableEffects" -> {
                    getAvailableEffects(result)
                }
                "updateShoePosition" -> {
                    val arData = call.argument<Map<String, Any>>("arData")
                    updateShoePosition(arData, result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun initializeDeepAR(licenseKey: String?, result: MethodChannel.Result) {
        try {
            // Initialize DeepAR with license key
            Log.d("DeepAR", "Initializing DeepAR with license: $licenseKey")
            
            // Create DeepAR view
            deepARView = DeepARView(this)
            
            result.success(true)
        } catch (e: Exception) {
            Log.e("DeepAR", "Failed to initialize DeepAR", e)
            result.success(false)
        }
    }
    
    private fun startARSession(result: MethodChannel.Result) {
        try {
            // Start AR session
            Log.d("DeepAR", "Starting AR session")
            
            // Add DeepAR view to the activity
            if (deepARView != null && !isARActive) {
                runOnUiThread {
                    val rootView = findViewById<View>(android.R.id.content)
                    if (rootView is FrameLayout) {
                        rootView.addView(deepARView)
                        isARActive = true
                    }
                }
            }
            
            result.success(true)
        } catch (e: Exception) {
            Log.e("DeepAR", "Failed to start AR session", e)
            result.success(false)
        }
    }
    
    private fun stopARSession(result: MethodChannel.Result) {
        try {
            // Stop AR session
            Log.d("DeepAR", "Stopping AR session")
            
            // Remove DeepAR view from the activity
            if (deepARView != null && isARActive) {
                runOnUiThread {
                    val rootView = findViewById<View>(android.R.id.content)
                    if (rootView is FrameLayout) {
                        rootView.removeView(deepARView)
                        isARActive = false
                    }
                }
            }
            
            result.success(true)
        } catch (e: Exception) {
            Log.e("DeepAR", "Failed to stop AR session", e)
            result.success(false)
        }
    }
    
    private fun switchEffect(effectPath: String?, result: MethodChannel.Result) {
        try {
            // Switch AR effect
            Log.d("DeepAR", "Switching effect to: $effectPath")
            
            // Update the DeepAR view with the new effect
            if (deepARView != null) {
                runOnUiThread {
                    deepARView?.loadEffect(effectPath ?: "")
                }
            }
            
            result.success(true)
        } catch (e: Exception) {
            Log.e("DeepAR", "Failed to switch effect", e)
            result.success(false)
        }
    }
    
    private fun updateShoePosition(arData: Map<String, Any>?, result: MethodChannel.Result) {
        try {
            if (arData == null) {
                result.success(false)
                return
            }

            Log.d("DeepAR", "Updating shoe position with data: $arData")
            
            // Extract foot tracking data
            val landmarks = arData["landmarks"] as? Map<String, Any>
            val rotation = (arData["rotation"] as? Number)?.toFloat() ?: 0f
            val scale = arData["scale"] as? Map<String, Any>

            if (landmarks == null || scale == null) {
                result.success(false)
                return
            }

            // Convert data to DeepAR format
            val jsonData = JSONObject().apply {
                put("landmarks", JSONObject(landmarks))
                put("rotation", rotation)
                put("scale", JSONObject(scale))
            }

            // Update the DeepAR view with the new position
            if (deepARView != null) {
                runOnUiThread {
                    deepARView?.updateShoePosition(jsonData)
                }
            }
            
            result.success(true)
        } catch (e: Exception) {
            Log.e("DeepAR", "Failed to update shoe position", e)
            result.success(false)
        }
    }
    
    private fun takeScreenshot(result: MethodChannel.Result) {
        try {
            // Take screenshot
            Log.d("DeepAR", "Taking screenshot")
            result.success("screenshot_path.jpg")
        } catch (e: Exception) {
            Log.e("DeepAR", "Failed to take screenshot", e)
            result.success(null)
        }
    }
    
    private fun startRecording(result: MethodChannel.Result) {
        try {
            // Start recording
            Log.d("DeepAR", "Starting recording")
            result.success(true)
        } catch (e: Exception) {
            Log.e("DeepAR", "Failed to start recording", e)
            result.success(false)
        }
    }
    
    private fun stopRecording(result: MethodChannel.Result) {
        try {
            // Stop recording
            Log.d("DeepAR", "Stopping recording")
            result.success("video_path.mp4")
        } catch (e: Exception) {
            Log.e("DeepAR", "Failed to stop recording", e)
            result.success(null)
        }
    }
    
    private fun getAvailableEffects(result: MethodChannel.Result) {
        try {
            // Get available effects
            val effects = listOf("effect1.deepar", "effect2.deepar", "effect3.deepar")
            result.success(effects)
        } catch (e: Exception) {
            Log.e("DeepAR", "Failed to get available effects", e)
            result.success(emptyList<String>())
        }
    }
}

// DeepAR View class that simulates AR camera
class DeepARView(context: Context) : FrameLayout(context) {
    private var currentEffect: String? = null
    private var shoePosition: JSONObject? = null
    
    init {
        // Set up the AR camera view
        setBackgroundColor(android.graphics.Color.BLACK)
        
        // Add AR camera preview (simulated)
        val cameraPreview = TextView(context).apply {
            text = "🎯 DeepAR Camera Active\nPoint camera at your feet"
            setTextColor(android.graphics.Color.WHITE)
            textSize = 18f
            gravity = android.view.Gravity.CENTER
        }
        
        addView(cameraPreview)
    }
    
    fun loadEffect(effectPath: String) {
        // Simulate loading an effect
        currentEffect = effectPath
        val effectName = effectPath.split("/").lastOrNull() ?: "Unknown"
        Log.d("DeepAR", "Loading effect: $effectName")
        
        // Update the view to show the effect is active
        updatePreviewText()
    }

    fun updateShoePosition(position: JSONObject) {
        // Simulate updating shoe position
        shoePosition = position
        Log.d("DeepAR", "Updating shoe position: $position")
        
        // Update the view to show the new position
        updatePreviewText()
    }

    private fun updatePreviewText() {
        val cameraPreview = getChildAt(0) as? TextView
        val effectName = currentEffect?.split("/")?.lastOrNull() ?: "Unknown"
        val positionText = if (shoePosition != null) {
            "\nFoot detected at: ${shoePosition.toString()}"
        } else {
            "\nPoint camera at your feet"
        }
        
        cameraPreview?.text = "🎯 DeepAR Camera Active\nEffect: $effectName$positionText"
    }
}
