package com.mundialy.football

import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import org.json.JSONObject

class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        
        val data = remoteMessage.data
        val type = data["type"]
        
        Log.d("FCM", "Received message type: $type")

        if (type?.equals("GOAL", ignoreCase = true) == true) {
            val payload = parsePayload(data)
            GoalNotificationManager(this).showGoalNotification(payload)
        } else if (type?.equals("MATCH_START", ignoreCase = true) == true) {
            val payload = parsePayload(data)
            GoalNotificationManager(this).showMatchStartNotification(payload)
        } else if (type?.equals("HALF_TIME", ignoreCase = true) == true) {
            val payload = parsePayload(data)
            GoalNotificationManager(this).showHalfTimeNotification(payload)
        } else if (type?.equals("FULL_TIME", ignoreCase = true) == true) {
            val payload = parsePayload(data)
            GoalNotificationManager(this).showFullTimeNotification(payload)
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
