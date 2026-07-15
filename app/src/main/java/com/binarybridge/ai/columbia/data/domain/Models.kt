package com.binarybridge.ai.columbia.data.domain

import kotlinx.serialization.Serializable

/** Chế độ sinh video. */
enum class GenMode { TEXT, IMAGE }

/** Độ phân giải hỗ trợ (giá trị khớp API Wan; 1080P gated premium). */
enum class Resolution(val api: String, val label: String, val baseCost: Int, val premium: Boolean) {
    R720("720P", "720P", 20, false),
    R1080("1080P", "1080P HD", 40, true)
}

/** Một video đã tạo (lưu local). */
@Serializable
data class Creation(
    val id: String,
    val prompt: String,
    val mode: String,            // GenMode.name
    val videoPath: String,       // đường dẫn file mp4 trong filesDir
    val thumbPath: String,       // đường dẫn thumbnail (jpg) hoặc rỗng
    val resolution: String,      // "720P"/"1080P"
    val ratio: String,           // "9:16"...
    val durationSec: Int,
    val createdAt: Long
)

/** Trending effect ở Home (áp cho image-to-video). */
data class Effect(
    val id: String,
    val name: String,
    val promptTemplate: String,
    val colorSeed: Long          // màu placeholder cho thumbnail cho tới khi có asset
)

/** Gói credit (mua = stub IAP). */
data class CreditPack(
    val id: String,
    val credits: Int,
    val extraPercent: Int,       // 0 = không extra
    val priceLabel: String,
    val popular: Boolean
)

/** Danh mục tĩnh — giữ trong Kotlin cho gọn (Addendum: thay cho các file assets json). */
object Catalog {
    val effects = listOf(
        Effect("hug", "AI Hug", "Two people share a warm heartfelt hug, gentle camera push-in, soft glow", 0xFFF472B6),
        Effect("kiss", "AI Kiss", "A romantic slow kiss at golden hour, cinematic, soft bokeh", 0xFFA855F7),
        Effect("muscle", "Muscle", "The person flexes powerful muscles, dynamic energy aura, dramatic light", 0xFF10B981),
        Effect("baby", "Baby", "Turn the person into an adorable smiling baby, playful, bright", 0xFFF59E0B),
        Effect("aging", "Aging", "The person gracefully ages over time, subtle morph, nostalgic", 0xFF6D28D9),
        Effect("polaroid", "Polaroid", "A polaroid photo comes to life, retro film look, gentle motion", 0xFFC026D3),
    )

    val ideas = listOf(
        "Neon city at night", "A space cat floating", "Cherry blossom falling",
        "Time-lapse of a flower blooming, macro, vivid colors", "Ocean waves at sunset",
        "A dragon soaring through clouds", "Rain on a window, cozy", "Aurora over mountains"
    )

    val packs = listOf(
        CreditPack("p50", 50, 0, "$1.00", false),
        CreditPack("p190", 190, 27, "$3.00", false),
        CreditPack("p300", 300, 20, "$5.00", true),
        CreditPack("p700", 700, 40, "$9.99", false),
    )
}
