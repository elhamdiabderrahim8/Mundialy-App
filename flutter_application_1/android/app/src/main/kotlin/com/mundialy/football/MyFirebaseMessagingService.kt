package com.mundialy.football

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)

        val data = remoteMessage.data
        val manager = GoalNotificationManager(applicationContext)
        
        if (data["type"] == "GOAL") {
            val payload = mutableMapOf<String, Any?>()
            payload.putAll(data)
            manager.showGoalNotification(payload)
        } else if (data["type"] == "MATCH_START") {
            val payload = mutableMapOf<String, Any?>()
            payload.putAll(data)
            manager.showMatchStartNotification(payload)
        } else if (data["type"] == "HALF_TIME") {
            val payload = mutableMapOf<String, Any?>()
            payload.putAll(data)
            manager.showHalfTimeNotification(payload)
        } else if (data["type"] == "FULL_TIME") {
            val payload = mutableMapOf<String, Any?>()
            payload.putAll(data)
            manager.showFullTimeNotification(payload)
        }
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
    }
}
