#!/bin/bash
# Script to rebuild the Flutter app with proper native plugin initialization

set -e

echo "🧹 Cleaning Flutter build..."
flutter clean

echo "📦 Getting Flutter dependencies..."
flutter pub get

echo "🍎 Installing iOS pods..."
cd ios
pod install
cd ..

echo "🚀 Building and running app..."
echo "Note: This will do a full rebuild - DO NOT use hot restart after this!"
flutter run

echo "✅ Done! If you see initialization errors, make sure you did a FULL rebuild (not hot restart)"



