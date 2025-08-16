#!/bin/bash

# Colores para mejor visualización
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Directorio donde está el script (steins-gate-tools)
SCRIPT_DIR="$HOME/steins-gate-tools"
mkdir -p "$SCRIPT_DIR"

# Archivo principal donde se acumula todo el texto (en la misma carpeta del script)
MAIN_TEXT_FILE="$SCRIPT_DIR/steins_gate_text.txt"

# Crear archivo principal si no existe (sin encabezado inicial)
if [ ! -f "$MAIN_TEXT_FILE" ]; then
    touch "$MAIN_TEXT_FILE"
fi

echo -e "${BLUE}🎮 Steins;Gate OCR - Extractor de Solo Texto v3.0${NC}"
echo "=================================================="
echo ""
echo -e "${YELLOW}📋 INSTRUCCIONES:${NC}"
echo "1. Abre PPSSPP y carga Steins;Gate"
echo "2. Espera a que aparezca NUEVO texto japonés"
echo "3. Presiona ENTER para capturar"
echo "4. Selecciona EXACTAMENTE la caja de texto"
echo "5. El texto se acumulará automáticamente en un archivo"
echo ""
echo -e "${GREEN}📄 Archivo de texto: $MAIN_TEXT_FILE${NC}"
echo ""

# Función para limpiar archivos temporales (solo imágenes)
cleanup_temp() {
    rm -f /tmp/steins_gate_*.png 2>/dev/null
}

# Función para preprocesar imagen específicamente para visual novels
preprocess_image() {
    local input_img="$1"
    local output_img="$2"
    
    # Múltiples pasos de procesamiento para mejorar OCR de kanjis
    convert "$input_img" \
        -resize 400% \
        -colorspace Gray \
        -contrast-stretch 2%x1% \
        -normalize \
        -sharpen 0x2 \
        -threshold 50% \
        -morphology Open Diamond:1 \
        -despeckle \
        "$output_img" 2>/dev/null
    
    if [ -f "$output_img" ]; then
        return 0
    else
        return 1
    fi
}

# Función para limpiar texto japonés
clean_japanese_text() {
    local input_text="$1"
    local output_text="$2"
    
    if [ -f "$input_text" ] && [ -s "$input_text" ]; then
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//' "$input_text" | \
        grep -v '^[[:space:]]*$' > "$output_text"
        
        if [ -s "$output_text" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

# Función para comparar con texto anterior
is_duplicate_text() {
    local new_text_file="$1"
    
    if [ ! -f "$new_text_file" ] || [ ! -s "$new_text_file" ]; then
        return 1
    fi
    
    local new_content=$(cat "$new_text_file" 2>/dev/null | tr -d '\n\r\t ' | head -c 100)
    
    if [ -z "$new_content" ]; then
        return 1
    fi
    
    # Comparar exactamente con la última línea no vacía del archivo principal
    if [ -f "$MAIN_TEXT_FILE" ] && [ -s "$MAIN_TEXT_FILE" ]; then
        local last_line=$(tail -1 "$MAIN_TEXT_FILE" | tr -d '\n\r\t ' | head -c 100)
        if [ "$new_content" = "$last_line" ]; then
            return 0  # Es duplicado exacto
        fi
    fi
    return 1  # No es duplicado
}

# Función para agregar texto al archivo principal
append_text_to_main() {
    local text_file="$1"
    
    if [ -f "$text_file" ] && [ -s "$text_file" ]; then
        # Si el archivo principal no existe, crearlo sin encabezado especial
        if [ ! -f "$MAIN_TEXT_FILE" ]; then
            cat "$text_file" > "$MAIN_TEXT_FILE"
        else
            # Solo agregar una nueva línea y el texto
            echo "" >> "$MAIN_TEXT_FILE"
            cat "$text_file" >> "$MAIN_TEXT_FILE"
        fi
        return 0
    else
        return 1
    fi
}

# Limpiar archivos temporales al inicio
cleanup_temp

# Contador de capturas
capture_count=0

while true; do
    echo ""
    read -p "$(echo -e ${GREEN}📸 Presiona ENTER para capturar texto japonés [q para salir]:${NC}) "
    
    if [[ "$REPLY" == "q" ]] || [[ "$REPLY" == "Q" ]]; then
        echo -e "${BLUE}👋 ¡Hasta luego!${NC}"
        echo -e "${BLUE}📄 Texto completo guardado en: $MAIN_TEXT_FILE${NC}"
        cleanup_temp
        exit 0
    fi
    
    ((capture_count++))
    echo -e "${YELLOW}📸 Captura #$capture_count - Selecciona SOLO la caja de diálogo:${NC}"
    
    # Capturar con scrot
    scrot -s -q 100 /tmp/steins_gate_raw.png 2>/dev/null
    
    # Verificar captura
    if [ ! -f "/tmp/steins_gate_raw.png" ]; then
        import /tmp/steins_gate_raw.png 2>/dev/null
    fi
    
    if [ -f "/tmp/steins_gate_raw.png" ]; then
        # Procesar imagen (temporal)
        if preprocess_image "/tmp/steins_gate_raw.png" "/tmp/steins_gate_processed.png"; then
            
            echo -e "${PURPLE}🔍 Extrayendo texto japonés...${NC}"
            
            # Limpiar archivos de salida anteriores
            rm -f /tmp/steins_gate_output*.txt 2>/dev/null
            
            # OCR con múltiples configuraciones
            tesseract /tmp/steins_gate_processed.png /tmp/steins_gate_output1 -l jpn --psm 6 --oem 1 \
                -c preserve_interword_spaces=1 \
                -c tessedit_char_blacklist='|[]{}()<>' 2>/dev/null
            
            tesseract /tmp/steins_gate_processed.png /tmp/steins_gate_output2 -l jpn --psm 3 --oem 1 \
                -c preserve_interword_spaces=1 2>/dev/null
            
            tesseract /tmp/steins_gate_processed.png /tmp/steins_gate_output3 -l jpn --psm 7 --oem 1 2>/dev/null
            
            # Elegir el mejor resultado
            best_output=""
            max_length=0
            
            for i in 1 2 3; do
                output="/tmp/steins_gate_output${i}.txt"
                if [ -f "$output" ] && [ -s "$output" ]; then
                    length=$(wc -c < "$output" 2>/dev/null || echo "0")
                    if [ "$length" -gt "$max_length" ]; then
                        max_length=$length
                        best_output="$output"
                    fi
                fi
            done
            
            if [ -n "$best_output" ] && [ -s "$best_output" ]; then
                # Limpiar el texto
                if clean_japanese_text "$best_output" "/tmp/steins_gate_final.txt"; then
                    
                    # Verificar si es texto duplicado
                    if is_duplicate_text "/tmp/steins_gate_final.txt"; then
                        echo -e "${YELLOW}⚠️ TEXTO DUPLICADO DETECTADO - No agregado${NC}"
                    else
                        # Mostrar resultado en consola
                        echo ""
                        echo -e "${GREEN}📝 NUEVO TEXTO EXTRAÍDO:${NC}"
                        echo "=================================="
                        cat /tmp/steins_gate_final.txt
                        echo "=================================="
                        
                        # Agregar al archivo principal
                        if append_text_to_main "/tmp/steins_gate_final.txt"; then
                            char_count=$(wc -m < "/tmp/steins_gate_final.txt" 2>/dev/null || echo "0")
                            total_lines=$(wc -l < "$MAIN_TEXT_FILE" 2>/dev/null || echo "0")
                            
                            echo -e "${GREEN}✅ Texto agregado al archivo principal${NC}"
                            echo -e "${BLUE}📊 Este fragmento: ${char_count} caracteres${NC}"
                            echo -e "${BLUE}📄 Total líneas en archivo: ${total_lines}${NC}"
                        else
                            echo -e "${RED}❌ Error al agregar texto al archivo principal${NC}"
                        fi
                    fi
                else
                    echo -e "${RED}❌ Error al limpiar el texto${NC}"
                fi
            else
                echo -e "${RED}❌ No se detectó texto japonés${NC}"
                echo ""
                echo -e "${YELLOW}💡 CONSEJOS:${NC}"
                echo "- Selecciona EXACTAMENTE la caja de texto"
                echo "- Asegúrate de que el texto sea claro y de buen tamaño"
                echo "- Evita bordes y elementos de la interfaz"
            fi
        else
            echo -e "${RED}❌ Error al procesar la imagen${NC}"
        fi
        
        # Limpiar imágenes temporales después de cada captura
        cleanup_temp
        
    else
        echo -e "${RED}❌ Error al capturar pantalla${NC}"
        echo -e "${YELLOW}💡 Instala: sudo apt install scrot imagemagick${NC}"
    fi
    
    # Mostrar estado del archivo
    if [ -f "$MAIN_TEXT_FILE" ]; then
        total_size=$(wc -c < "$MAIN_TEXT_FILE" 2>/dev/null || echo "0")
        echo -e "${BLUE}📈 Archivo actual: ${total_size} caracteres totales${NC}"
    fi
done