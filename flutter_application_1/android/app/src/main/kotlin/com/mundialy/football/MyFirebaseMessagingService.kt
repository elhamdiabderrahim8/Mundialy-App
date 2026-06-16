package com.mundialy.football

import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import org.json.JSONObject

class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        
        val data = remoteMessage.data
        val type = data["type"] ?: return
        
        Log.d("FCM", "Received message type: $type")

        val payload = parsePayload(data)

        when (type.uppercase()) {
            "GOAL" -> GoalNotificationManager.show(this, payload)
            "MATCH_START" -> MatchStartNotificationManager.show(this, payload)
            "HALF_TIME" -> HalfTimeNotificationManager.show(this, payload)
            "FULL_TIME" -> FullTimeNotificationManager.show(this, payload)
            else -> Log.w("FCM", "Unknown notification type: $type")
        }
    }

    private fun parsePayload(data: Map<String, String>): Map<String, Any?> {
        val result = mutableMapOf<String, Any?>()
        data.forEach { (key, value) ->
            if (value.trim().startsWith("{") || value.trim().startsWith("[")) {
                try {
                    result[key] = jsonToAny(JSONObject(value))
                } catch (e: Exception) {
                    result[key] = value
                }
            } else {
                result[key] = value
            }
        }
        return result
    }

    private fun jsonToAny(json: Any): Any? {
        if (json is JSONObject) {
            val map = mutableMapOf<String, Any?>()
            val keys = json.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                map[key] = jsonToAny(json.get(key))
            }
            return map
        } else if (json is org.json.JSONArray) {
            val list = mutableListOf<Any?>()
            for (i in 0 until json.length()) {
                list.add(jsonToAny(json.get(i)))
            }
            return list
        } else if (json == JSONObject.NULL) {
            return null
        }
        return json
    }
}
