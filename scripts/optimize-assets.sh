#!/bin/bash

# Script to analyze and optimize assets in the current Android project
# Usage: ./scripts/optimize-assets.sh (run from project root)

set -e

# Resolve project root (parent of scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo "📁 Project root: $PROJECT_ROOT"
echo ""
echo "🔍 Analyzing assets in current project..."
echo ""

# Find all modules with src/main (app, u_crop, imagepicker, etc.)
MODULES=$(find . -maxdepth 2 -type d -path "*/src/main" | sed 's|/src/main||' | sed 's|^\./||' | sort -u)

for MODULE in $MODULES; do
  [ -d "$MODULE" ] || continue
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📦 Module: $MODULE"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # 1. res/drawable and res/drawable-* (all densities)
  DRAWABLE_DIRS=$(find "$MODULE/src/main/res" -maxdepth 1 -type d -name "drawable*" 2>/dev/null || true)
  if [ -n "$DRAWABLE_DIRS" ]; then
    echo ""
    echo "📊 Top 15 largest files in res/drawable*:"
    find $DRAWABLE_DIRS -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" -o -name "*.gif" \) \
      -exec du -h {} + 2>/dev/null | sort -rh | head -15
  fi

  # 2. res/raw
  RAW_DIR="$MODULE/src/main/res/raw"
  if [ -d "$RAW_DIR" ]; then
    echo ""
    echo "📊 Files in res/raw:"
    du -sh "$RAW_DIR" 2>/dev/null
    find "$RAW_DIR" -type f -exec du -h {} + 2>/dev/null | sort -rh | head -10
  fi

  # 3. res/mipmap-*
  MIPMAP_DIRS=$(find "$MODULE/src/main/res" -maxdepth 1 -type d -name "mipmap*" 2>/dev/null || true)
  if [ -n "$MIPMAP_DIRS" ]; then
    echo ""
    echo "📊 Total mipmap size:"
    du -ch $MIPMAP_DIRS 2>/dev/null | tail -1
  fi

  # 4. assets folder
  ASSETS_DIR="$MODULE/src/main/assets"
  if [ -d "$ASSETS_DIR" ]; then
    echo ""
    echo "📊 Assets folder size:"
    du -sh "$ASSETS_DIR" 2>/dev/null
    echo ""
    echo "📊 Assets by subfolder/file:"
    du -sh "$ASSETS_DIR"/* 2>/dev/null | sort -rh || true
    echo ""
    echo "📊 Top 15 largest files in assets:"
    find "$ASSETS_DIR" -type f -exec du -h {} + 2>/dev/null | sort -rh | head -15
  fi

  echo ""
done

# Summary: detect large files by type
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 OPTIMIZATION CANDIDATES (files > 500KB)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Videos
VIDEOS=$(find . -path "*/src/main/assets/*" -type f \( -name "*.mp4" -o -name "*.webm" -o -name "*.mkv" \) -size +500k 2>/dev/null || true)
if [ -n "$VIDEOS" ]; then
  echo "🎬 Videos (>500KB):"
  echo "$VIDEOS" | while read f; do [ -n "$f" ] && du -h "$f" 2>/dev/null; done
  echo "   → Khuyến nghị: Nén với ffmpeg hoặc tải từ server"
  echo ""
fi

# GIFs
GIFS=$(find . -path "*/src/main/*" -type f -name "*.gif" -size +100k 2>/dev/null || true)
if [ -n "$GIFS" ]; then
  echo "🖼️  GIF files (>100KB):"
  echo "$GIFS" | while read f; do [ -n "$f" ] && du -h "$f" 2>/dev/null; done
  echo "   → Khuyến nghị: Chuyển sang WebP animated hoặc nén"
  echo ""
fi

# PNG/JPG (raster images)
RASTER=$(find . -path "*/src/main/*" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) -size +500k 2>/dev/null || true)
if [ -n "$RASTER" ]; then
  echo "🖼️  PNG/JPG files (>500KB):"
  echo "$RASTER" | while read f; do [ -n "$f" ] && du -h "$f" 2>/dev/null; done | head -20
  echo "   → Khuyến nghị: Chuyển sang WebP với cwebp -q 85"
  echo ""
fi

# Audio
AUDIO=$(find . -path "*/src/main/*" -type f \( -name "*.mp3" -o -name "*.wav" -o -name "*.ogg" \) -size +200k 2>/dev/null || true)
if [ -n "$AUDIO" ]; then
  echo "🔊 Audio files (>200KB):"
  echo "$AUDIO" | while read f; do [ -n "$f" ] && du -h "$f" 2>/dev/null; done
  echo "   → Khuyến nghị: Nén với ffmpeg -b:a 64k"
  echo ""
fi

# CSV/JSON (large data files)
DATA=$(find . -path "*/src/main/assets/*" -type f \( -name "*.csv" -o -name "*.json" \) -size +500k 2>/dev/null || true)
if [ -n "$DATA" ]; then
  echo "📄 Large data files (>500KB):"
  echo "$DATA" | while read f; do [ -n "$f" ] && du -h "$f" 2>/dev/null; done
  echo "   → Khuyến nghị: Lazy load hoặc compress"
  echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 Quick optimization commands:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Video:   ffmpeg -i input.mp4 -vcodec libx264 -crf 28 -preset slow output.mp4"
echo "PNG→WebP: cwebp -q 85 input.png -o output.webp"
echo "MP3:     ffmpeg -i input.mp3 -b:a 64k output.mp3"
echo ""
