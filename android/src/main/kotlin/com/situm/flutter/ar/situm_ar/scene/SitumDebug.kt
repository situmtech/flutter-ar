package com.situm.flutter.ar.situm_ar.scene

import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import es.situm.sdk.SitumSdk
import es.situm.sdk.communication.CommunicationConfigImpl
import es.situm.sdk.configuration.network.NetworkOptions
import es.situm.sdk.configuration.network.NetworkOptionsImpl
import es.situm.sdk.directions.DirectionsRequest
import es.situm.sdk.location.LocationRequest
import es.situm.sdk.model.cartography.BuildingInfo
import es.situm.sdk.model.directions.Route
import es.situm.sdk.model.location.Location
import es.situm.sdk.navigation.NavigationRequest
import es.situm.sdk.utils.Handler

class SitumDebug (val context: Context){

    val TAG = "> Situm"
    fun initSitum() {

        SitumSdk.init(context);


        // Acceder a los valores de meta-data
        val apiUser = "core@situm.com"
        val apiKey = ""
        if (apiUser == null || apiKey == null) {
            Log.e(TAG, "Situm API_KEY or API_USER not set")
            return
        };
        SitumSdk.configuration().setApiKey(apiUser, apiKey)
        SitumSdk.configuration().isUseRemoteConfig = true;


        startPositioning()


    }


    private fun startPositioning() {
        val locationRequest: LocationRequest = LocationRequest.Builder()
            .useWifi(true)
            .useBle(true)
            .useGps(true)
            .buildingIdentifier("12469").build()
        SitumSdk.locationManager().requestLocationUpdates(locationRequest)

    }

    fun calculateRoute(from: Location, toPoiId: String) {

        val directionsRequest: DirectionsRequest = DirectionsRequest.Builder()
            .from(from)
            .to(toPoiId)
            .build()

        SitumSdk.directionsManager().requestDirections(directionsRequest, object : Handler<Route?> {
            override fun onSuccess(route: Route?) {
                Log.w(TAG,"> Situm route: ${route.toString()}")
                if (route != null) {
                    requestNavigationUpdates(route)
                }
            }


            override fun onFailure(error: es.situm.sdk.error.Error?) {
                Log.w(TAG,"> error estimating route: $error")
            }
        })
    }

    fun requestNavigationUpdates(route:Route){
        val navigationRequest: NavigationRequest = NavigationRequest.Builder()
            .route(route!!)
            .build()
        SitumSdk.navigationManager().requestNavigationUpdates(navigationRequest)
    }

}