#!/bin/bash

# Colores para mejor visualización
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Crear directorio para historial si no existe
HISTORY_DIR="$HOME/steins_gate_ocr_history"
mkdir -p "$HISTORY_DIR"

echo -e "${BLUE}🎮 Steins;Gate OCR - Extractor Mejorado v2.0${NC}"
echo "=================================================="
echo ""
echo -e "${YELLOW}📋 INSTRUCCIONES MEJORADAS:${NC}"
echo "1. Abre PPSSPP y carga Steins;Gate"
echo "2. Espera a que aparezca NUEVO texto japonés"
echo "3. Presiona ENTER para capturar"
echo "4. Selecciona EXACTAMENTE la caja de texto (sin bordes ni menús)"
echo "5. El script detectará automáticamente texto duplicado"
echo ""

# Función para limpiar archivos temporales
cleanup_temp() {
    rm -f /tmp/steins_gate_*.png 2>/dev/null
}

# Función para preprocesar imagen específicamente para visual novels
preprocess_image() {
    local input_img="$1"
    local output_img="$2"
    
    echo -e "${PURPLE}🔧 Procesando imagen: $(basename "$input_img") -> $(basename "$output_img")${NC}"
    
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
        "$output_img"
    
    if [ -f "$output_img" ]; then
        echo -e "${GREEN}✅ Imagen procesada correctamente${NC}"
        return 0
    else
        echo -e "${RED}❌ Error al procesar imagen${NC}"
        return 1
    fi
}

# Función para limpiar texto japonés
clean_japanese_text() {
    local input_text="$1"
    local output_text="$2"
    
    # Leer el texto y limpiarlo
    if [ -f "$input_text" ] && [ -s "$input_text" ]; then
        # Limpiar y escribir al archivo de salida
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//' "$input_text" | \
        grep -v '^[[:space:]]*$' > "$output_text"
        
        # Verificar que el archivo de salida tiene contenido
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
    local history_dir="$2"
    
    if [ ! -f "$new_text_file" ] || [ ! -s "$new_text_file" ]; then
        return 1
    fi
    
    # Obtener el contenido del nuevo texto
    local new_content=$(cat "$new_text_file" 2>/dev/null | tr -d '\n\r\t ' | head -c 200)
    
    if [ -z "$new_content" ]; then
        return 1
    fi
    
    # Comparar con los últimos 5 archivos
    for prev_file in $(ls -t "$history_dir"/steins_gate_text_*.txt 2>/dev/null | head -5); do
        if [ -f "$prev_file" ]; then
            local prev_content=$(cat "$prev_file" 2>/dev/null | tr -d '\n\r\t ' | head -c 200)
            if [ "$new_content" = "$prev_content" ]; then
                return 0  # Es duplicado
            fi
        fi
    done
    return 1  # No es duplicado
}

# Limpiar archivos temporales al inicio
cleanup_temp

while true; do
    echo ""
    read -p "$(echo -e ${GREEN}📸 Presiona ENTER para capturar texto japonés [q para salir]:${NC}) "
    
    if [[ "$REPLY" == "q" ]] || [[ "$REPLY" == "Q" ]]; then
        echo -e "${BLUE}👋 ¡Hasta luego!${NC}"
        cleanup_temp
        exit 0
    fi
    
    echo -e "${YELLOW}📸 Capturando región... Selecciona SOLO la caja de diálogo:${NC}"
    
    # Capturar con scrot
    scrot -s -q 100 /tmp/steins_gate_raw.png 2>/dev/null
    
    # Verificar captura
    if [ ! -f "/tmp/steins_gate_raw.png" ]; then
        echo -e "${RED}❌ No se capturó imagen con scrot. Intentando con ImageMagick...${NC}"
        import /tmp/steins_gate_raw.png 2>/dev/null
    fi
    
    if [ -f "/tmp/steins_gate_raw.png" ]; then
        echo -e "${GREEN}✅ Imagen capturada: $(ls -lh /tmp/steins_gate_raw.png | awk '{print $5}')${NC}"
        
        # Procesar imagen
        if preprocess_image "/tmp/steins_gate_raw.png" "/tmp/steins_gate_processed.png"; then
            
            # OCR con múltiples configuraciones
            echo -e "${PURPLE}🔍 Extrayendo texto japonés...${NC}"
            
            # Limpiar archivos de salida anteriores
            rm -f /tmp/steins_gate_output*.txt 2>/dev/null
            
            # Método 1: PSM 6 para bloques de texto uniforme
            echo -e "${PURPLE}   Método 1: PSM 6 (bloques de texto)${NC}"
            tesseract /tmp/steins_gate_processed.png /tmp/steins_gate_output1 -l jpn --psm 6 --oem 1 \
                -c preserve_interword_spaces=1 \
                -c tessedit_char_blacklist='|[]{}()<>' 2>/dev/null
            
            # Método 2: PSM 3 como respaldo
            echo -e "${PURPLE}   Método 2: PSM 3 (página completa)${NC}"
            tesseract /tmp/steins_gate_processed.png /tmp/steins_gate_output2 -l jpn --psm 3 --oem 1 \
                -c preserve_interword_spaces=1 2>/dev/null
            
            # Método 3: PSM 7 para líneas de texto
            echo -e "${PURPLE}   Método 3: PSM 7 (líneas de texto)${NC}"
            tesseract /tmp/steins_gate_processed.png /tmp/steins_gate_output3 -l jpn --psm 7 --oem 1 2>/dev/null
            
            # Verificar qué archivos se crearon
            echo -e "${BLUE}📋 Archivos generados por OCR:${NC}"
            for i in 1 2 3; do
                output_file="/tmp/steins_gate_output${i}.txt"
                if [ -f "$output_file" ]; then
                    size=$(wc -c < "$output_file" 2>/dev/null || echo "0")
                    echo "   - Método $i: $size caracteres"
                else
                    echo "   - Método $i: NO GENERADO"
                fi
            done
            
            # Elegir el mejor resultado (el más largo que tenga contenido)
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
                echo -e "${GREEN}🏆 Mejor resultado: $(basename "$best_output") con $max_length caracteres${NC}"
                
                # Limpiar el texto
                if clean_japanese_text "$best_output" "/tmp/steins_gate_final.txt"; then
                    
                    echo -e "${GREEN}✅ Texto limpiado correctamente${NC}"
                    
                    # Verificar contenido final
                    final_size=$(wc -c < "/tmp/steins_gate_final.txt" 2>/dev/null || echo "0")
                    echo -e "${BLUE}📏 Texto final: $final_size caracteres${NC}"
                    
                    # Verificar si es texto duplicado
                    if is_duplicate_text "/tmp/steins_gate_final.txt" "$HISTORY_DIR"; then
                        echo -e "${YELLOW}⚠️ TEXTO DUPLICADO DETECTADO${NC}"
                        echo -e "${YELLOW}Este texto ya fue capturado anteriormente.${NC}"
                    else
                        # Mostrar resultado
                        echo ""
                        echo -e "${GREEN}📝 TEXTO EXTRAÍDO DE STEINS;GATE:${NC}"
                        echo "=================================="
                        cat /tmp/steins_gate_final.txt
                        echo "=================================="
                        echo ""
                        
                        # Guardar en historial con timestamp
                        timestamp=$(date "+%Y%m%d_%H%M%S")
                        output_file="$HISTORY_DIR/steins_gate_text_${timestamp}.txt"
                        
                        # Copiar el archivo
                        cp "/tmp/steins_gate_final.txt" "$output_file"
                        
                        if [ -f "$output_file" ]; then
                            echo -e "${GREEN}💾 Texto guardado en: $output_file${NC}"
                            
                            # Mostrar estadísticas
                            char_count=$(wc -m < "$output_file" 2>/dev/null || echo "0")
                            line_count=$(wc -l < "$output_file" 2>/dev/null || echo "0")
                            echo -e "${BLUE}📊 Estadísticas: ${char_count} caracteres, ${line_count} líneas${NC}"
                            
                            # Mostrar ruta completa
                            echo -e "${BLUE}📂 Ruta completa: $(realpath "$output_file")${NC}"
                        else
                            echo -e "${RED}❌ Error al guardar el archivo${NC}"
                        fi
                    fi
                else
                    echo -e "${RED}❌ Error al limpiar el texto${NC}"
                fi
            else
                echo -e "${RED}❌ No se detectó texto japonés en ningún método${NC}"
                echo ""
                echo -e "${YELLOW}💡 CONSEJOS PARA MEJOR RECONOCIMIENTO:${NC}"
                echo "- Selecciona EXACTAMENTE la caja de texto (sin bordes blancos/negros)"
                echo "- Asegúrate de que el texto sea claro y de buen tamaño"
                echo "- Evita seleccionar botones, menús o elementos de la interfaz"
                echo "- El texto debe ser la parte principal de tu selección"
                echo "- Si el texto es muy pequeño, acerca la cámara en PPSSPP"
                
                # Mostrar información de debug
                echo -e "${BLUE}🔍 Debug - Archivos OCR generados:${NC}"
                ls -la /tmp/steins_gate_output*.txt 2>/dev/null || echo "   Ningún archivo generado"
            fi
        else
            echo -e "${RED}❌ Error al procesar la imagen${NC}"
        fi
        
        echo -e "${BLUE}🖼️ Archivos temporales en /tmp/ para revisión${NC}"
        echo "   - Imagen original: /tmp/steins_gate_raw.png"
        echo "   - Imagen procesada: /tmp/steins_gate_processed.png"
        
    else
        echo -e "${RED}❌ Error al capturar pantalla${NC}"
        echo -e "${YELLOW}💡 Asegúrate de tener 'scrot' instalado: sudo apt install scrot${NC}"
        echo -e "${YELLOW}💡 O 'imagemagick': sudo apt install imagemagick${NC}"
    fi
done