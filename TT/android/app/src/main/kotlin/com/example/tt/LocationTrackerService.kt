package com.example.tt

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import kotlin.math.cos
import kotlin.math.sin

class LocationTrackerService : Service(), SensorEventListener {

    private lateinit var locationManager: LocationManager
    private lateinit var sensorManager: SensorManager
    private var stepSensor: Sensor? = null
    private var rotationSensor: Sensor? = null

    private val CHANNEL_ID = "LocationTrackerChannel"
    
    private var currentAzimuth: Float = 0f
    private val STRIDE_LENGTH_METERS = 0.75

    companion object {
        var isTracking = false
        var lastLocation: Location? = null
        var locationUpdateListener: ((Location) -> Unit)? = null
    }

    override fun onCreate() {
        super.onCreate()
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        
        stepSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)
        rotationSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Travel Tracker Active")
            .setContentText("Your location is being tracked in the background.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .build()

        startForeground(1, notification)
        isTracking = true
        startLocationUpdates()
        startSensorUpdates()

        return START_STICKY
    }

    private fun startLocationUpdates() {
        try {
            // Request updates every 5 seconds (5000ms)
            locationManager.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                5000L,
                0f,
                locationListener
            )
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    private fun startSensorUpdates() {
        stepSensor?.let { sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL) }
        rotationSensor?.let { sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL) }
    }

    private val locationListener = object : LocationListener {
        override fun onLocationChanged(location: Location) {
            lastLocation = location
            // Send to Flutter
            locationUpdateListener?.invoke(location)
        }
        override fun onProviderEnabled(provider: String) {}
        override fun onProviderDisabled(provider: String) {}
        override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) {}
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null) return
        
        if (event.sensor.type == Sensor.TYPE_ROTATION_VECTOR) {
            val rotationMatrix = FloatArray(9)
            SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
            val orientationAngles = FloatArray(3)
            SensorManager.getOrientation(rotationMatrix, orientationAngles)
            currentAzimuth = orientationAngles[0] // Azimuth in radians
        } else if (event.sensor.type == Sensor.TYPE_STEP_DETECTOR) {
            // Apply dead reckoning if GPS accuracy is poor (> 20 meters)
            val loc = lastLocation
            if (loc != null && loc.accuracy > 20f) {
                applyDeadReckoning(loc)
            }
        }
    }

    private fun applyDeadReckoning(baseLocation: Location) {
        val earthRadius = 6378137.0 // meters

        // Coordinate offsets in radians
        val dLat = (STRIDE_LENGTH_METERS * cos(currentAzimuth.toDouble())) / earthRadius
        val dLng = (STRIDE_LENGTH_METERS * sin(currentAzimuth.toDouble())) / (earthRadius * cos(Math.toRadians(baseLocation.latitude)))

        val newLat = baseLocation.latitude + Math.toDegrees(dLat)
        val newLng = baseLocation.longitude + Math.toDegrees(dLng)

        val newLocation = Location("DeadReckoning")
        newLocation.latitude = newLat
        newLocation.longitude = newLng
        newLocation.accuracy = baseLocation.accuracy + 1f // Decrease accuracy gradually
        newLocation.time = System.currentTimeMillis()
        
        lastLocation = newLocation
        locationUpdateListener?.invoke(newLocation)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onDestroy() {
        super.onDestroy()
        locationManager.removeUpdates(locationListener)
        sensorManager.unregisterListener(this)
        isTracking = false
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Location Tracker Service Channel",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }
}
