package com.saludnow.app

import android.content.Context
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.fitness.FitnessLocal
import com.google.android.gms.fitness.FitnessStatusCodes
import com.google.android.gms.fitness.LocalRecordingClient
import com.google.android.gms.fitness.data.LocalDataType
import com.google.android.gms.fitness.data.LocalField
import com.google.android.gms.fitness.request.LocalDataReadRequest
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks
import io.flutter.plugin.common.MethodChannel
import java.time.Instant
import java.time.ZoneId
import java.util.concurrent.TimeUnit

/** Reads account-scoped daily totals from the handset's background recording. */
class BackgroundStepRecording(private val context: Context) {
    // Minimum Google Play services version documented for step-only recording.
    private companion object {
        const val MIN_STEPS_PLAY_SERVICES_VERSION = 241_500_000
    }

    private val prefs = context.getSharedPreferences("step_recording", Context.MODE_PRIVATE)
    private val type = LocalDataType.TYPE_STEP_COUNT_DELTA

    fun refresh(account: String, seed: Int, history: Boolean, result: MethodChannel.Result) {
        if (!available()) {
            result.success(null)
            return
        }
        val client = FitnessLocal.getLocalRecordingClient(context)
        val owner = prefs.getString("owner", null)
        val firstAt = prefs.getLong("startedAt", 0L)
        val task = if (owner == account && firstAt != 0L) {
            read(client, firstAt, prefs.getInt("seed", 0), history).continueWithTask { read ->
                val error = read.exception
                if (error is ApiException && error.statusCode == FitnessStatusCodes.API_EXCEPTION) {
                    subscribe(client, account, seed, history)
                } else {
                    read
                }
            }
        } else if (owner != null) {
            clearOwner(account)
            client.unsubscribe(type).continueWithTask { subscribe(client, account, seed, history) }
        } else {
            clearOwner(account)
            subscribe(client, account, seed, history)
        }

        task.addOnSuccessListener { counts ->
            result.success(if (prefs.getString("owner", null) == account) counts else null)
        }.addOnFailureListener {
            result.error("step_recording", "No se pudo consultar el registro de pasos.", null)
        }
    }

    fun stop(account: String?, result: MethodChannel.Result) {
        if (account != null && prefs.getString("owner", null) != account) {
            result.success(null)
            return
        }
        prefs.edit().remove("owner").remove("startedAt").remove("seed").apply()
        if (!available()) {
            result.success(null)
            return
        }
        FitnessLocal.getLocalRecordingClient(context).unsubscribe(type).addOnCompleteListener {
            result.success(null)
        }
    }

    private fun available() = GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(
        context, MIN_STEPS_PLAY_SERVICES_VERSION,
    ) == ConnectionResult.SUCCESS

    private fun clearOwner(account: String) {
        prefs.edit().putString("owner", account).remove("startedAt").remove("seed").apply()
    }

    private fun subscribe(
        client: LocalRecordingClient, account: String, seed: Int, history: Boolean,
    ): Task<Map<String, Int>> {
        if (prefs.getString("owner", null) != account) {
            return Tasks.forResult(emptyMap())
        }
        val start = System.currentTimeMillis()
        return client.subscribe(type).onSuccessTask {
            if (prefs.getString("owner", null) != account) {
                return@onSuccessTask Tasks.forResult(emptyMap())
            }
            prefs.edit().putLong("startedAt", start)
                .putInt("seed", seed).apply()
            read(client, start, seed, history)
        }
    }

    private fun read(
        client: LocalRecordingClient, firstAt: Long, seed: Int, history: Boolean,
    ): Task<Map<String, Int>> {
        val zone = ZoneId.systemDefault()
        val now = Instant.now()
        val first = Instant.ofEpochMilli(firstAt)
        val today = now.atZone(zone).toLocalDate()
        val firstDay = first.atZone(zone).toLocalDate()
        val oldest = today.minusDays(if (history) 9 else 1)
        val startDay = maxOf(firstDay, oldest)
        val tasks = generateSequence(startDay) { it.plusDays(1) }.takeWhile { it <= today }.map { day ->
            val start = maxOf(first, day.atStartOfDay(zone).toInstant())
            val end = minOf(now, day.plusDays(1).atStartOfDay(zone).toInstant())
            if (!start.isBefore(end)) return@map null
            val request = LocalDataReadRequest.Builder()
                .aggregate(type)
                .bucketByTime(1, TimeUnit.DAYS)
                .setTimeRange(start.toEpochMilli(), end.toEpochMilli(), TimeUnit.MILLISECONDS)
                .build()
            client.readData(request).onSuccessTask { response ->
                val count = response.buckets.flatMap { it.dataSets }.flatMap { it.dataPoints }
                    .sumOf { it.getValue(LocalField.FIELD_STEPS).asInt().toLong() }
                val baseline = if (day == firstDay) seed else 0
                Tasks.forResult(day.toString() to (baseline + count).coerceIn(0L, 100_000L).toInt())
            }
        }.filterNotNull().toList()
        return Tasks.whenAllSuccess<Pair<String, Int>>(tasks).onSuccessTask {
            Tasks.forResult(it.toMap())
        }
    }
}
