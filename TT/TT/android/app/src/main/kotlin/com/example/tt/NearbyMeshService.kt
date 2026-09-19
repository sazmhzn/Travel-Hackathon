package com.example.tt

import android.content.Context
import android.util.Log
import android.os.Build
import com.google.android.gms.nearby.Nearby
import com.google.android.gms.nearby.connection.*
import com.google.gson.Gson

class NearbyMeshService(private val context: Context) {
    private val TAG = "NearbyMeshService"
    private val STRATEGY = Strategy.P2P_CLUSTER
    private val SERVICE_ID = "com.example.tt.MESH_RELAY"
    
    private val connectionsClient = Nearby.getConnectionsClient(context)
    private var connectedEndpointId: String? = null
    
    var payloadListener: ((String) -> Unit)? = null

    // Endpoint Discovery Callback
    private val endpointDiscoveryCallback = object : EndpointDiscoveryCallback() {
        override fun onEndpointFound(endpointId: String, info: DiscoveredEndpointInfo) {
            Log.d(TAG, "Endpoint found: ${info.endpointName}, connecting...")
            connectionsClient.requestConnection(
                Build.MODEL,
                endpointId,
                connectionLifecycleCallback
            ).addOnSuccessListener {
                Log.d(TAG, "Connection request sent to $endpointId")
            }.addOnFailureListener { e ->
                Log.e(TAG, "Failed to request connection", e)
            }
        }

        override fun onEndpointLost(endpointId: String) {
            Log.d(TAG, "Endpoint lost: $endpointId")
        }
    }

    // Connection Lifecycle Callback
    private val connectionLifecycleCallback = object : ConnectionLifecycleCallback() {
        override fun onConnectionInitiated(endpointId: String, connectionInfo: ConnectionInfo) {
            Log.d(TAG, "Connection initiated with ${connectionInfo.endpointName}. Accepting automatically.")
            connectionsClient.acceptConnection(endpointId, payloadCallback)
        }

        override fun onConnectionResult(endpointId: String, result: ConnectionResolution) {
            when (result.status.statusCode) {
                ConnectionsStatusCodes.STATUS_OK -> {
                    Log.d(TAG, "Connected successfully to $endpointId")
                    connectedEndpointId = endpointId
                }
                ConnectionsStatusCodes.STATUS_CONNECTION_REJECTED -> {
                    Log.d(TAG, "Connection rejected by $endpointId")
                }
                else -> {
                    Log.d(TAG, "Connection failed to $endpointId with code ${result.status.statusCode}")
                }
            }
        }

        override fun onDisconnected(endpointId: String) {
            Log.d(TAG, "Disconnected from $endpointId")
            if (connectedEndpointId == endpointId) {
                connectedEndpointId = null
            }
        }
    }

    // Payload Callback
    private val payloadCallback = object : PayloadCallback() {
        override fun onPayloadReceived(endpointId: String, payload: Payload) {
            if (payload.type == Payload.Type.BYTES) {
                val data = payload.asBytes()?.let { String(it, Charsets.UTF_8) }
                Log.d(TAG, "Payload received from $endpointId: $data")
                data?.let { payloadListener?.invoke(it) }
            }
        }

        override fun onPayloadTransferUpdate(endpointId: String, update: PayloadTransferUpdate) {}
    }

    fun startAdvertising(userId: String) {
        val advertisingOptions = AdvertisingOptions.Builder().setStrategy(STRATEGY).build()
        connectionsClient.startAdvertising(
            userId,
            SERVICE_ID,
            connectionLifecycleCallback,
            advertisingOptions
        ).addOnSuccessListener {
            Log.d(TAG, "Started Advertising")
        }.addOnFailureListener { e ->
            Log.e(TAG, "Failed to start advertising", e)
        }
    }

    fun startDiscovery() {
        val discoveryOptions = DiscoveryOptions.Builder().setStrategy(STRATEGY).build()
        connectionsClient.startDiscovery(
            SERVICE_ID,
            endpointDiscoveryCallback,
            discoveryOptions
        ).addOnSuccessListener {
            Log.d(TAG, "Started Discovery")
        }.addOnFailureListener { e ->
            Log.e(TAG, "Failed to start discovery", e)
        }
    }

    fun stopAllEndpoints() {
        connectionsClient.stopAdvertising()
        connectionsClient.stopDiscovery()
        connectionsClient.stopAllEndpoints()
        connectedEndpointId = null
        Log.d(TAG, "Stopped all mesh networking")
    }

    fun broadcastPayload(jsonPayload: String) {
        connectedEndpointId?.let { endpointId ->
            val payload = Payload.fromBytes(jsonPayload.toByteArray(Charsets.UTF_8))
            connectionsClient.sendPayload(endpointId, payload)
        } ?: run {
            Log.d(TAG, "Cannot broadcast, no connected endpoints")
        }
    }
}
