import os
import sys
import subprocess
# import re
# import urllib.parse
# import json
from .text_processing import convert_to_romaji, correct_ocr_errors
from .ocr import preprocess_image
from .translation import translate_text

SCRIPT_DIR = os.path.expanduser("~/steins-gate-tools")
COMBINED_FILE = os.path.join(SCRIPT_DIR, "steins_gate_combined.txt")

def check_dependencies():
    missing = []
    for cmd in ['scrot', 'tesseract', 'convert', 'curl', 'jq', 'python3']:
        if subprocess.run(['which', cmd], capture_output=True).returncode != 0:
            missing.append(cmd)
    if missing:
        print(f"\033[0;31m🚫 Missing dependencies: {' '.join(missing)}\033[0m")
        return False
    return True

def install_japanese_deps():
    try:
        import pykakasi
        print("\033[0;32m✨ pykakasi available\033[0m")
    except ImportError:
        print("\033[0;31m❌ Instala pykakasi: pip install pykakasi\033[0m")
        sys.exit(1)

def clean_japanese_text(input_path: str, output_path: str):
    if os.path.exists(input_path):
        with open(input_path, 'r') as f_in:
            content = f_in.read()
        cleaned_content = ' '.join([line.strip() for line in content.splitlines() if line.strip()])
        with open(output_path, 'w') as f_out:
            f_out.write(cleaned_content)

def is_duplicate_text(new_text_path: str) -> bool:
    if not os.path.exists(new_text_path):
        return True
    with open(new_text_path, 'r') as f:
        new_content = f.read().replace('\n', '').replace('\r', '').replace('\t', '').replace(' ', '')[:100]
    if not new_content:
        return True
    if os.path.exists(COMBINED_FILE):
        with open(COMBINED_FILE, 'r') as f:
            lines = f.readlines()
            # Look for lines starting with "📝 JAP: " and get the last 5
            jp_lines = [line.replace("📝 JAP: ", "").strip() for line in lines if line.startswith("📝 JAP: ")]
            if len(jp_lines) >= 1:
                last_content = "".join(jp_lines[-1:]).replace('\n', '').replace('\r', '').replace('\t', '').replace(' ', '')[:100]
                if new_content == last_content:
                    return True
    return False

def append_text_to_combined(jp_text: str, romaji_text: str, translated_text: str):
    with open(COMBINED_FILE, 'a') as f:
        f.write("\n")
        f.write(f"📝 JAP: {jp_text}\n")
        f.write(f"🔤 ROM: {romaji_text}\n")
        f.write(f"🌐 ENG: {translated_text}\n")
        f.write("----------------------------------------\n")

def cleanup_temp():
    temp_files = [f for f in os.listdir("/tmp") if f.startswith("steins_gate_") and 
                  (f.endswith(".png") or f.endswith(".txt"))]
    for f in temp_files:
        os.remove(os.path.join("/tmp", f))

def main():
    os.makedirs(SCRIPT_DIR, exist_ok=True)
    if not os.path.exists(COMBINED_FILE):
        open(COMBINED_FILE, 'a').close() # Create if not exists

    if not check_dependencies():
        sys.exit(1)
    install_japanese_deps()
    cleanup_temp()

    count = 0
    print("\033[0;32m➡️ Press 'q' + ENTER to exit\033[0m")
    print("")

    while True:
        user_input = input(f"\033[0;32m📷 ENTER to capture:\033[0m ")
        if user_input.lower() == 'q':
            break

        count += 1
        print(f"\033[1;33m  Capture #{count}: Select ONLY the dialog box\033[0m")
        
        # Use 'import' for Wayland, 'scrot' for X11
        if os.environ.get("XDG_SESSION_TYPE") == "wayland":
            capture_command = ['import', '/tmp/steins_gate_raw.png']
        else:
            capture_command = ['scrot', '-s', '-q', '100', '/tmp/steins_gate_raw.png']
        
        try:
            subprocess.run(capture_command, check=True, capture_output=True)
        except subprocess.CalledProcessError:
            print(f"\033[0;31m🛑 Error capturing screen\033[0m")
            continue

        if os.path.exists("/tmp/steins_gate_raw.png"):
            print("\033[0;34m⚙️  Processing image...\033[0m")
            preprocess_image("/tmp/steins_gate_raw.png", "/tmp/steins_gate_processed.png")
            subprocess.run(['tesseract', '/tmp/steins_gate_processed.png', '/tmp/steins_gate_output', '-l', 'jpn', '--psm', '6', '--oem', '1'],
                           capture_output=True)
            clean_japanese_text("/tmp/steins_gate_output.txt", "/tmp/steins_gate_final.txt")

            if not is_duplicate_text("/tmp/steins_gate_final.txt"):
                with open("/tmp/steins_gate_final.txt", 'r') as f:
                    jp_text = f.read().strip()
                
                if jp_text and jp_text != " ":
                    print(f"\033[0;32m💬 JAPANESE TEXT:\033[0m\n{jp_text}")
                    print("")
                    
                    print("\033[0;35m🏮 Converting to romaji...\033[0m")
                    romaji_text = convert_to_romaji(jp_text)
                    with open("/tmp/steins_gate_romaji.txt", 'w') as f: # Save romaji to file
                        f.write(romaji_text)
                    print(f"\033[0;35m⛩️  ROMAJI:\033[0m\n{romaji_text}")
                    print("")
                    
                    print("\033[0;36m🌍 Translating...\033[0m")
                    tr_text = translate_text(jp_text)
                    with open("/tmp/steins_gate_translation.txt", 'w') as f: # Save translation to file
                        f.write(tr_text)
                    print(f"\033[0;36m🗣️ TRANSLATION:\033[0m\n{tr_text}")
                    print("")
                    
                    append_text_to_combined(jp_text, romaji_text, tr_text)
                    print(f"\033[0;32m💾 Saved to combined file\033[0m")
                else:
                    print(f"\033[0;31m❌ No Japanese text detected\033[0m")
            else:
                print(f"\033[1;33m⚠️ DUPLICATE TEXT DETECTED\033[0m")
            cleanup_temp()
        else:
            print(f"\033[0;31m❌ Error capturing screen\033[0m")
        print("")

    print(f"\033[0;34m👋 Goodbye!\033[0m")
    print(f"\033[0;34m📄 Combined file saved to: {COMBINED_FILE}\033[0m")
    cleanup_temp()

if __name__ == "__main__":
    main()
