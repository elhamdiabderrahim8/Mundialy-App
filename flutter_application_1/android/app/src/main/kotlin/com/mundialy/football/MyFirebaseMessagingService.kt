package com.mundialy.football

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(msg: RemoteMessage) {
        val type = msg.data["type"]
        val ctx = applicationContext
        
        when (type) {
            "GOAL" -> GoalNotificationManager.show(ctx, msg.data)
            "MATCH_START" -> MatchStartNotificationManager.show(ctx, msg.data)
            "HALF_TIME" -> HalfTimeNotificationManager.show(ctx, msg.data)
            "FULL_TIME" -> FullTimeNotificationManager.show(ctx, msg.data)
        }
    }
    
    override fun onNewToken(token: String) {
        super.onNewToken(token)
    }
}
