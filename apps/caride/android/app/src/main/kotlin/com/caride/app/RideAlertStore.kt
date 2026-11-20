package com.caride.app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

object RideAlertStore {
    private const val PREFS_NAME = "caride_ride_alerts_prefs"
    private const val KEY_SEEN_IDS = "seen_ride_ids"
    private const val KEY_DECLINED_IDS = "declined_ride_ids"
    private const val KEY_PENDING_INTENT = "pending_ride_intent"
    private const val MAX_RING_SIZE = 50
    private const val INTENT_TTL_MS = 5 * 60_000L

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun notificationIdForRide(rideId: String): Int =
        50_000 + (rideId.hashCode() and 0x7FFF)

    @Synchronized
    fun isSeen(context: Context, rideId: String): Boolean {
        return readRing(context, KEY_SEEN_IDS).contains(rideId)
    }

    @Synchronized
    fun isDeclined(context: Context, rideId: String): Boolean {
        return readRing(context, KEY_DECLINED_IDS).contains(rideId)
    }

    @Synchronized
    fun isHandledOrDeclined(context: Context, rideId: String): Boolean {
        return isSeen(context, rideId) || isDeclined(context, rideId)
    }

    @Synchronized
    fun markSeen(context: Context, rideId: String) {
        appendRing(context, KEY_SEEN_IDS, rideId)
    }

    @Synchronized
    fun markDeclined(context: Context, rideId: String) {
        appendRing(context, KEY_SEEN_IDS, rideId)
        appendRing(context, KEY_DECLINED_IDS, rideId)
    }

    @Synchronized
    fun getDeclinedIds(context: Context): List<String> = readRing(context, KEY_DECLINED_IDS)

    @Synchronized
    fun savePendingIntent(context: Context, rideId: String, type: String, action: String = "open") {
        val json = JSONObject().apply {
            put("rideId", rideId)
            put("type", type)
            put("action", action)
            put("timestampMs", System.currentTimeMillis())
        }
        prefs(context).edit().putString(KEY_PENDING_INTENT, json.toString()).apply()
    }

    @Synchronized
    fun consumePendingIntent(context: Context): Map<String, String>? {
        val sp = prefs(context)
        val raw = sp.getString(KEY_PENDING_INTENT, null) ?: return null
        sp.edit().remove(KEY_PENDING_INTENT).apply()
        return try {
            val json = JSONObject(raw)
            val ts = json.optLong("timestampMs", 0L)
            if (ts > 0 && System.currentTimeMillis() - ts > INTENT_TTL_MS) {
                return null
            }
            val rideId = json.optString("rideId", "").trim()
            val type = json.optString("type", "").trim()
            if (rideId.isEmpty() || type.isEmpty()) {
                null
            } else {
                mapOf(
                    "rideId" to rideId,
                    "type" to type,
                    "action" to json.optString("action", "open"),
                )
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun readRing(context: Context, key: String): MutableList<String> {
        val raw = prefs(context).getString(key, null) ?: return mutableListOf()
        return try {
            val arr = JSONArray(raw)
            val list = mutableListOf<String>()
            for (i in 0 until arr.length()) {
                val item = arr.optString(i, "").trim()
                if (item.isNotEmpty()) list.add(item)
            }
            list
        } catch (_: Exception) {
            mutableListOf()
        }
    }

    private fun appendRing(context: Context, key: String, value: String) {
        val clean = value.trim()
        if (clean.isEmpty()) return
        val list = readRing(context, key)
        list.remove(clean)
        list.add(clean)
        while (list.size > MAX_RING_SIZE) {
            list.removeAt(0)
        }
        val arr = JSONArray(list)
        prefs(context).edit().putString(key, arr.toString()).apply()
    }
}
