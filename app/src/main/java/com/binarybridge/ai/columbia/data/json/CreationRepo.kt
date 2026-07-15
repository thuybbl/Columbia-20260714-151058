package com.binarybridge.ai.columbia.data.json

import android.content.Context
import android.util.Log
import com.binarybridge.ai.columbia.data.domain.Creation
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import java.io.File

/** Singleton lưu danh sách Creation dạng JSON trong filesDir, expose qua StateFlow. */
object CreationRepo {
    private const val TAG = "ColumbiaCreationRepo"
    private val json = Json { ignoreUnknownKeys = true; prettyPrint = false }
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private lateinit var file: File

    private val _creations = MutableStateFlow<List<Creation>>(emptyList())
    val creations: StateFlow<List<Creation>> = _creations.asStateFlow()

    fun init(context: Context) {
        file = File(context.applicationContext.filesDir, "creations.json")
        scope.launch {
            try {
                if (file.exists()) {
                    val text = file.readText()
                    if (text.isNotBlank())
                        _creations.value = json.decodeFromString(ListSerializer(Creation.serializer()), text)
                }
            } catch (e: Exception) {
                Log.e(TAG, "load: ${e.message}")
            }
        }
    }

    fun add(creation: Creation) {
        _creations.value = listOf(creation) + _creations.value
        persist()
    }

    fun remove(id: String) {
        _creations.value = _creations.value.filterNot { it.id == id }
        persist()
    }

    fun byId(id: String): Creation? = _creations.value.firstOrNull { it.id == id }

    private fun persist() {
        val snapshot = _creations.value
        scope.launch {
            try {
                file.writeText(json.encodeToString(ListSerializer(Creation.serializer()), snapshot))
            } catch (e: Exception) {
                Log.e(TAG, "persist: ${e.message}")
            }
        }
    }
}
