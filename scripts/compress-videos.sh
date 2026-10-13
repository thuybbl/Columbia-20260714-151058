#!/bin/bash

# Script để nén video trong assets/videos
# Sử dụng: ./scripts/compress-videos.sh [quality]
# quality: high (CRF 23, 1.5Mbps) hoặc medium (CRF 28, 1Mbps)
# Mặc định: high

QUALITY=${1:-high}
VIDEOS_DIR="app/src/main/assets/videos"
BACKUP_DIR="app/src/main/assets/videos_backup"

# Kiểm tra ffmpeg
if ! command -v ffmpeg &> /dev/null; then
    echo "❌ ffmpeg không được cài đặt!"
    echo "Cài đặt: brew install ffmpeg (macOS) hoặc apt-get install ffmpeg (Linux)"
    exit 1
fi

# Tạo backup
echo "📦 Đang tạo backup videos..."
mkdir -p "$BACKUP_DIR"
cp -r "$VIDEOS_DIR"/* "$BACKUP_DIR/" 2>/dev/null
echo "✅ Backup đã được lưu tại: $BACKUP_DIR"

# Thiết lập tham số nén
if [ "$QUALITY" = "high" ]; then
    CRF=23
    BITRATE="1.5M"
    MAXRATE="2M"
    BUFSIZE="3M"
    echo "🎬 Chế độ: HIGH QUALITY (CRF 23, 1.5Mbps)"
elif [ "$QUALITY" = "medium" ]; then
    CRF=28
    BITRATE="1M"
    MAXRATE="1.5M"
    BUFSIZE="2M"
    echo "🎬 Chế độ: MEDIUM QUALITY (CRF 28, 1Mbps) - Tiết kiệm nhiều hơn"
else
    echo "❌ Quality không hợp lệ! Sử dụng: high hoặc medium"
    exit 1
fi

# Hàm nén video
compress_video() {
    local input="$1"
    local output="${input%.mp4}_compressed.mp4"
    local filename=$(basename "$input")
    
    echo ""
    echo "🔄 Đang nén: $filename"
    
    # Lấy thông tin video gốc
    local width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1 "$input" 2>/dev/null | cut -d= -f2)
    local height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1 "$input" 2>/dev/null | cut -d= -f2)
    local original_size=$(du -h "$input" | cut -f1)
    
    echo "   Kích thước gốc: $original_size"
    echo "   Độ phân giải: ${width}x${height}"
    
    # Nén video
    ffmpeg -i "$input" \
        -vcodec libx264 \
        -crf $CRF \
        -preset medium \
        -vf "scale=${width}:${height}" \
        -b:v $BITRATE \
        -maxrate $MAXRATE \
        -bufsize $BUFSIZE \
        -movflags +faststart \
        -y \
        "$output" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        local new_size=$(du -h "$output" | cut -f1)
        echo "   ✅ Hoàn thành! Kích thước mới: $new_size"
        
        # Tính phần trăm giảm
        local original_bytes=$(stat -f%z "$input" 2>/dev/null || stat -c%s "$input" 2>/dev/null)
        local new_bytes=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null)
        local reduction=$((100 - (new_bytes * 100 / original_bytes)))
        echo "   📉 Giảm: ~${reduction}%"
    else
        echo "   ❌ Lỗi khi nén!"
        return 1
    fi
}

# Nén các video lớn
echo ""
echo "🎥 Bắt đầu nén video..."

# video_iap.mp4 (19MB - cần nén nhất)
if [ -f "$VIDEOS_DIR/video_iap.mp4" ]; then
    compress_video "$VIDEOS_DIR/video_iap.mp4"
fi

# splash.mp4 (6.9MB - cần nén)
if [ -f "$VIDEOS_DIR/splash.mp4" ]; then
    compress_video "$VIDEOS_DIR/splash.mp4"
fi

# smoke.mp4 (840KB - có thể tối ưu)
if [ -f "$VIDEOS_DIR/smoke.mp4" ]; then
    compress_video "$VIDEOS_DIR/smoke.mp4"
fi

# video_discord.mp4 (nếu có)
if [ -f "$VIDEOS_DIR/video_discord.mp4" ]; then
    compress_video "$VIDEOS_DIR/video_discord.mp4"
fi

echo ""
echo "✅ Hoàn thành nén video!"
echo ""
echo "📝 Bước tiếp theo:"
echo "   1. Kiểm tra chất lượng video đã nén (file *_compressed.mp4)"
echo "   2. Nếu OK, thay thế file gốc:"
echo "      mv $VIDEOS_DIR/video_iap_compressed.mp4 $VIDEOS_DIR/video_iap.mp4"
echo "   3. Xóa file backup nếu không cần: rm -rf $BACKUP_DIR"
echo ""
echo "💡 Tip: So sánh video trên điện thoại trước khi thay thế!"

