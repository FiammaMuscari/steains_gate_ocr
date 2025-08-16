#!/bin/bash

# Colores para mejor visualización
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Directorio del script
SCRIPT_DIR="$HOME/steins-gate-tools"
mkdir -p "$SCRIPT_DIR"

COMBINED_FILE="$SCRIPT_DIR/steins_gate_combined.txt"
touch "$COMBINED_FILE"

echo -e "${BLUE}🎮 Steins;Gate OCR + Traductor Mejorado${NC}"
echo "=================================================="
echo ""

# Dependencias
check_dependencies() {
    local missing=""
    for cmd in scrot tesseract convert curl jq python3; do
        command -v $cmd &>/dev/null || missing="$missing $cmd"
    done
    if [ -n "$missing" ]; then
        echo -e "${RED}❌ Faltan dependencias:${missing}${NC}"
        return 1
    fi
    return 0
}

# Corrección de errores comunes de OCR
correct_ocr_errors() {
    local text="$1"
    text=$(echo "$text" | sed \
        -e 's/でたよき/んでたよ/g' \
        -e 's/まゆ!り/まゆり/g' \
        -e 's/條/場/g' \
        -e 's/一 槍/一緒/g')
    echo "$text"
}

# Preprocesar imagen
preprocess_image() {
    local input="$1" output="$2"
    convert "$input" \
        -resize 400% \
        -colorspace Gray \
        -contrast-stretch 2%x1% \
        -normalize \
        -sharpen 0x2 \
        -threshold 50% \
        -morphology Open Diamond:1 \
        -despeckle \
        "$output" 2>/dev/null
}

# Limpiar texto japonés
clean_japanese_text() {
    local input="$1" output="$2"
    if [ -f "$input" ]; then
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//' "$input" | \
        grep -v '^[[:space:]]*$' | \
        xargs > "$output"
    fi
}

# Verificar duplicado en el archivo combinado
is_duplicate_text() {
    local new="$1"
    local new_content=$(cat "$new" | tr -d '\n\r\t ' | head -c 100)
    [ -z "$new_content" ] && return 1
    if [ -f "$COMBINED_FILE" ]; then
        local last=$(tail -n 3 "$COMBINED_FILE" | tr -d '\n\r\t ' | head -c 100)
        [ "$new_content" = "$last" ] && return 0
    fi
    return 1
}

# Traducir texto
translate_text() {
    local text="$1" output="$2" translation=""
    text=$(correct_ocr_errors "$text")
    IFS='。、\n' read -ra phrases <<< "$text"
    for phrase in "${phrases[@]}"; do
        [ -z "$phrase" ] && continue
        encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$phrase'''))")
        part=$(curl -s "https://translate.googleapis.com/translate_a/single?client=gtx&sl=ja&tl=en&dt=t&q=$encoded" \
            | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d[0][0][0] if d and d[0] else '')")
        [ -z "$part" ] && part="[Untranslated]"
        translation="$translation $part"
    done
    translation=$(echo "$translation" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    echo "$translation" > "$output"
    echo "$translation"
}

# Agregar texto + traducción al archivo combinado
append_text_to_combined() {
    local jp="$1" tr="$2"
    {
        echo ""
        echo "📝 JAP: $jp"
        echo "🌐 ENG: $tr"
        echo "----------------------------------------"
    } >> "$COMBINED_FILE"
}

# Limpiar temporales
cleanup_temp() { rm -f /tmp/steins_gate_*.png /tmp/steins_gate_*.txt 2>/dev/null; }

# Verificar dependencias
check_dependencies || exit 1
cleanup_temp

count=0
while true; do
    read -p "$(echo -e ${GREEN}📸 ENTER para capturar:${NC}) "
    [[ "$REPLY" =~ ^[qQ]$ ]] && break

    ((count++))
    echo -e "${YELLOW}📸 Captura #$count: Selecciona SOLO la caja de diálogo${NC}"
    scrot -s -q 100 /tmp/steins_gate_raw.png || import /tmp/steins_gate_raw.png

    if [ -f "/tmp/steins_gate_raw.png" ]; then
        preprocess_image "/tmp/steins_gate_raw.png" "/tmp/steins_gate_processed.png"
        tesseract /tmp/steins_gate_processed.png /tmp/steins_gate_output -l jpn --psm 6 --oem 1 2>/dev/null
        clean_japanese_text "/tmp/steins_gate_output.txt" "/tmp/steins_gate_final.txt"

        if ! is_duplicate_text "/tmp/steins_gate_final.txt"; then
            jp_text=$(cat /tmp/steins_gate_final.txt)
            echo -e "${GREEN}📝 TEXTO JAPONÉS:${NC}\n$jp_text"
            tr_text=$(translate_text "$jp_text" "/tmp/steins_gate_translation.txt")
            echo -e "${CYAN}🌐 TRADUCCIÓN:${NC}\n$tr_text"
            append_text_to_combined "$jp_text" "$tr_text"
        else
            echo -e "${YELLOW}⚠️ TEXTO DUPLICADO DETECTADO${NC}"
        fi
        cleanup_temp
    else
        echo -e "${RED}❌ Error al capturar pantalla${NC}"
    fi
done

echo -e "${BLUE}👋 ¡Hasta luego!${NC}"
echo -e "${BLUE}📄 Archivo combinado guardado en: $COMBINED_FILE${NC}"
cleanup_temp
