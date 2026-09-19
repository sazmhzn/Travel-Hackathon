package com.example.tt

import android.content.Intent
import android.location.Location
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val METHOD_CHANNEL = "com.example.tt/location_control"
    private val EVENT_CHANNEL = "com.example.tt/location_updates"
    
    private val MESH_METHOD_CHANNEL = "com.example.tt/mesh_control"
    private val MESH_EVENT_CHANNEL = "com.example.tt/mesh_updates"

    private var eventSink: EventChannel.EventSink? = null
    private var meshEventSink: EventChannel.EventSink? = null
    
    private lateinit var nearbyMeshService: NearbyMeshService

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        nearbyMeshService = NearbyMeshService(this)

        // Location Channels
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startTracking" -> {
                    startLocationService()
                    result.success(true)
                }
                "stopTracking" -> {
                    stopLocationService()
                    result.success(true)
                }
                "isTracking" -> {
                    result.success(LocationTrackerService.isTracking)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    LocationTrackerService.locationUpdateListener = { location: Location ->
                        runOnUiThread {
                            eventSink?.success(mapOf(
                                "latitude" to location.latitude,
                                "longitude" to location.longitude,
                                "accuracy" to location.accuracy
                            ))
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    LocationTrackerService.locationUpdateListener = null
                }
            }
        )
        
        // Mesh Channels
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MESH_METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAdvertising" -> {
                    val userId = call.argument<String>("userId") ?: "UnknownUser"
                    nearbyMeshService.startAdvertising(userId)
                    result.success(true)
                }
                "startDiscovery" -> {
                    nearbyMeshService.startDiscovery()
                    result.success(true)
                }
                "stopMesh" -> {
                    nearbyMeshService.stopAllEndpoints()
                    result.success(true)
                }
                "broadcastPayload" -> {
                    val payload = call.argument<String>("payload")
                    if (payload != null) {
                        nearbyMeshService.broadcastPayload(payload)
                        result.success(true)
                    } else {
                        result.error("INVALID_PAYLOAD", "Payload cannot be null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, MESH_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    meshEventSink = events
                    nearbyMeshService.payloadListener = { jsonPayload: String ->
                        runOnUiThread {
                            meshEventSink?.success(jsonPayload)
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    meshEventSink = null
                    nearbyMeshService.payloadListener = null
                }
            }
        )
    }

    private fun startLocationService() {
        val serviceIntent = Intent(this, LocationTrackerService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun stopLocationService() {
        val serviceIntent = Intent(this, LocationTrackerService::class.java)
        stopService(serviceIntent)
    }
}
