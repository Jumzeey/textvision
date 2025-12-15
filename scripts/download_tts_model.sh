#!/bin/bash

# Script to download Sherpa-ONNX TTS model
# Downloads a VITS-Piper English model from the official repository

set -e

echo "Downloading Sherpa-ONNX TTS model..."

# Create assets directory if it doesn't exist
mkdir -p assets/sherpa-onnx-tts

# Model URL - using a VITS-Piper English model
# You can change this to other models from https://k2-fsa.github.io/sherpa-onnx/tts/models.html
MODEL_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_US-amy-medium.onnx"
TOKENS_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_US-amy-medium.tokens.txt"

# Download model
echo "Downloading model file..."
curl -L -o assets/sherpa-onnx-tts/model.onnx "$MODEL_URL"

# Download tokens file if available
echo "Downloading tokens file..."
curl -L -o assets/sherpa-onnx-tts/tokens.txt "$TOKENS_URL" || echo "Tokens file not available, continuing..."

echo "Model downloaded successfully!"
echo "Model location: assets/sherpa-onnx-tts/model.onnx"



