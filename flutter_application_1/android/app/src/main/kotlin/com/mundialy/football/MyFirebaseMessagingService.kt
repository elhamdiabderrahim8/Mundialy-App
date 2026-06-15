package com.mundialy.football

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)

        val fcmData = remoteMessage.data
        val manager = GoalNotificationManager(this)
        
        val msgType: String? = fcmData["type"]
        
        if (msgType == "GOAL") {
            val payload = mutableMapOf<String, Any?>()
            payload.putAll(fcmData)
            manager.showGoalNotification(payload)
        } else if (msgType == "MATCH_START") {
            val payload = mutableMapOf<String, Any?>()
            payload.putAll(fcmData)
            manager.showMatchStartNotification(payload)
        } else if (typeMatches(msgType, "HALF_TIME")) {
            val payload = mutableMapOf<String, Any?>()
            payload.putAll(fcmData)
            manager.showHalfTimeNotification(payload)
        } else if (typeMatches(msgType, "FULL_TIME")) {
            val payload = mutableMapOf<String, Any?>()
            payload.putAll(fcmData)
            manager.showFullTimeNotification(payload)
        }
    }

    private fun typeMatches(type: String?, target: String): Boolean {
        return type != null && type.equals(target, ignoreCase = true)
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
    }
}
