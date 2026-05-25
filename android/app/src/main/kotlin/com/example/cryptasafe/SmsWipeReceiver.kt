package com.example.cryptasafe

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log

class SmsWipeReceiver : BroadcastReceiver() {

    companion object {
        // Change this to your own secret phrase — keep it hard to guess
        const val WIPE_COMMAND = "CRYPTASAFE_WIPE_NOW"
        const val TAG = "SmsWipeReceiver"
        const val WIPE_TRIGGERED_KEY = "wipe_triggered"
        const val PREFS_NAME = "cryptasafe_prefs"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)

        for (message in messages) {
            val body = message.messageBody?.trim() ?: continue
            Log.d(TAG, "SMS received, checking for wipe command...")

            if (body == WIPE_COMMAND) {
                Log.d(TAG, "Wipe command received! Triggering vault wipe.")
                triggerWipe(context)
                return
            }
        }
    }

    private fun triggerWipe(context: Context) {
        // Set a flag in SharedPreferences that Flutter will read on next launch
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(WIPE_TRIGGERED_KEY, true).apply()

        // Also try to launch the app to complete the wipe immediately
        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
        if (launchIntent != null) {
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            launchIntent.putExtra("wipe_triggered", true)
            context.startActivity(launchIntent)
        }

        Log.d(TAG, "Wipe flag set. App will wipe on next launch.")
    }
}
