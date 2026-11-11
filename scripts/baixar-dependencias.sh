#!/bin/zsh
# Baixa whisper.cpp e llama.cpp pré-compilados e opcionalmente os modelos padrão.
set -e
cd "$(dirname "$0")/.."

WHISPER_TAG=b5130
LLAMA_TAG=b12262

BAIXAR_MODELOS=false
AVISAR_SEM_FLAG=false

if [[ "$1" == "--com-modelos" ]]; then
  BAIXAR_MODELOS=true
elif [[ "$1" == "--sem-modelos" ]]; then
  BAIXAR_MODELOS=false
elif [[ -z "$1" ]]; then
  BAIXAR_MODELOS=false
  AVISAR_SEM_FLAG=true
elif [[ "$1" == "-h" || "$1" == "--help" ]]; then
  echo "Uso: $0 [--sem-modelos | --com-modelos]"
  echo "  --sem-modelos (padrão): Baixa apenas os xcframeworks (whisper.cpp e llama.cpp) necessários para compilar."
  echo "  --com-modelos: Baixa também os modelos Whisper large-v3-turbo e Qwen2.5-7B (~5.7 GB)."
  exit 0
else
  echo "Opção desconhecida: $1"
  echo "Uso: $0 [--sem-modelos | --com-modelos]"
  exit 1
fi

echo "==> Verificando dependências de compilação (xcframeworks)..."

if [ ! -d Vendor/build-apple/whisper.xcframework ]; then
  echo "Baixando whisper.xcframework ($WHISPER_TAG)..."
  mkdir -p Vendor && cd Vendor
  curl -L -o whisper.zip "https://github.com/ggml-org/whisper.cpp/releases/download/$WHISPER_TAG/whisper-$WHISPER_TAG-xcframework.zip"
  unzip -q whisper.zip && rm whisper.zip
  cd ..
fi

if [ ! -d Vendor/build-apple/llama.xcframework ]; then
  echo "Baixando llama.xcframework ($LLAMA_TAG)..."
  mkdir -p Vendor && cd Vendor
  curl -L -o llama.zip "https://github.com/ggml-org/llama.cpp/releases/download/$LLAMA_TAG/llama-$LLAMA_TAG-xcframework.zip"
  unzip -q llama.zip && rm llama.zip
  cd ..
fi

echo "✓ Dependências C/C++ prontas em Vendor/build-apple/"

if [ "$BAIXAR_MODELOS" = true ]; then
  MODELOS="${DITTADO_MODELS_DIR:-$HOME/Library/Application Support/Dittado/Models}"
  mkdir -p "$MODELOS"

  if [ ! -f "$MODELOS/ggml-large-v3-turbo-q8_0.bin" ]; then
    echo "Baixando modelo Whisper (large-v3-turbo)..."
    curl -L -C - -o "$MODELOS/ggml-large-v3-turbo-q8_0.bin.part" \
      https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q8_0.bin
    mv "$MODELOS/ggml-large-v3-turbo-q8_0.bin.part" "$MODELOS/ggml-large-v3-turbo-q8_0.bin"
  fi

  QWEN_7B_FILE="qwen2.5-7b-instruct-q4_k_m.gguf"
  QWEN_7B_SHA256="65b8fcd92af6b4fefa935c625d1ac27ea29dcb6ee14589c55a8f115ceaaa1423"
  QWEN_7B_URL="https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf"

  if [ ! -f "$MODELOS/$QWEN_7B_FILE" ]; then
    echo "Baixando modelo LLM Qwen2.5-7B-Instruct Q4_K_M (Apache-2.0)..."
    curl -L -C - --fail --retry 3 --retry-delay 2 \
      -o "$MODELOS/$QWEN_7B_FILE.part" "$QWEN_7B_URL"

    if command -v shasum >/dev/null 2>&1; then
      echo "Verificando SHA256 do modelo 7B..."
      CALC_HASH=$(shasum -a 256 "$MODELOS/$QWEN_7B_FILE.part" | awk '{print $1}')
      if [ "$CALC_HASH" = "$QWEN_7B_SHA256" ]; then
        echo "SHA256 verificado com sucesso!"
      else
        echo "Aviso: Hash SHA256 não confere (calculado: $CALC_HASH, esperado: $QWEN_7B_SHA256). Prosseguindo com o arquivo baixado."
      fi
    fi

    mv "$MODELOS/$QWEN_7B_FILE.part" "$MODELOS/$QWEN_7B_FILE"
  fi
  echo "✓ Modelos prontos em $MODELOS"
else
  if [ "$AVISAR_SEM_FLAG" = true ]; then
    echo ""
    echo "ℹ️  Nenhum modelo de IA foi baixado (modo padrão para compilação rápida)."
    echo "    Para baixar os modelos padrão (~5.7 GB) via script, use: ./scripts/baixar-dependencias.sh --com-modelos"
    echo "    Ou baixe os modelos interativamente pela tela inicial do Dittado ao abrir o app."
    echo ""
  fi
fi

echo "Dependências OK"
