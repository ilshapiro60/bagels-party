package com.pawparty.paw_party

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.google.android.gms.maps.model.LatLng
import com.google.android.libraries.places.api.Places
import com.google.android.libraries.places.api.model.CircularBounds
import com.google.android.libraries.places.api.model.Place
import com.google.android.libraries.places.api.net.PlacesClient
import com.google.android.libraries.places.api.net.SearchNearbyRequest

class MainActivity : FlutterActivity() {

    private lateinit var placesClient: PlacesClient

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val appInfo = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
        val apiKey = appInfo.metaData?.getString("com.google.android.geo.API_KEY") ?: ""
        if (!Places.isInitialized()) {
            Places.initializeWithNewPlacesApiEnabled(applicationContext, apiKey)
        }
        placesClient = Places.createClient(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "searchNearbyVeterinaryCare" -> searchNearby(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun searchNearby(call: MethodCall, result: MethodChannel.Result) {
        val lat = call.argument<Double>("latitude")
        val lng = call.argument<Double>("longitude")
        if (lat == null || lng == null) {
            result.error("INVALID_ARGS", "latitude and longitude are required", null)
            return
        }
        val radius = call.argument<Double>("radiusMeters") ?: 8000.0
        val maxResults = call.argument<Int>("maxResultCount") ?: 20

        val fields = listOf(
            Place.Field.ID,
            Place.Field.DISPLAY_NAME,
            Place.Field.FORMATTED_ADDRESS,
            Place.Field.LOCATION,
        )
        val circle = CircularBounds.newInstance(LatLng(lat, lng), radius)
        val request = SearchNearbyRequest.builder(circle, fields)
            .setIncludedTypes(listOf("veterinary_care"))
            .setMaxResultCount(maxResults.coerceIn(1, 20))
            .setRankPreference(SearchNearbyRequest.RankPreference.DISTANCE)
            .build()

        placesClient.searchNearby(request)
            .addOnSuccessListener { response ->
                val places = response.places.mapNotNull { place ->
                    val id = place.id ?: return@mapNotNull null
                    val name = place.displayName ?: return@mapNotNull null
                    val loc = place.location ?: return@mapNotNull null
                    mapOf(
                        "placeId" to id,
                        "name" to name,
                        "address" to (place.formattedAddress ?: ""),
                        "latitude" to loc.latitude,
                        "longitude" to loc.longitude,
                    )
                }
                result.success(places)
            }
            .addOnFailureListener { e ->
                result.error("PLACES_ERROR", e.message ?: "Nearby search failed", null)
            }
    }

    companion object {
        private const val CHANNEL = "com.pawparty.paw_party/places"
    }
}
