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

        if (type == "GOAL") {
            val payload = parsePayload(data)
            GoalNotificationManager(this).showGoalNotification(payload)
        }
    }

    private fun parsePayload(data: Map<String, String>): Map<String, Any?> {
        val result = mutableMapOf<String, Any?>()
        data.forEach { (key, value) ->
            if (value.startsWith("{") || value.startsWith("[")) {
                try {
                    result[key] = jsonToMap(JSONObject(value))
                } catch (e: Exception) {
                    result[key] = value
                }
            } else {
                result[key] = value
            }
        }
        return result
    }

    private fun jsonToMap(json: JSONObject): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        val keys = json.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            var value = json.get(key)
            if (value is JSONObject) {
                value = jsonToMap(value)
            } else if (value == JSONObject.NULL) {
                value = null
            }
            map[key] = value
        }
        return map
    }
}
