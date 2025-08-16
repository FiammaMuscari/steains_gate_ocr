import subprocess
import json
import urllib.parse
from .text_processing import correct_ocr_errors
import re

def translate_text(text: str) -> str:
    text = correct_ocr_errors(text)
    phrases = re.split(r'[。、\n]', text)
    translation = []
    for phrase in phrases:
        if not phrase.strip():
            continue
        encoded_phrase = urllib.parse.quote(phrase)
        # Note: This uses a public Google Translate API which might have rate limits or change.
        # For a more robust solution, consider a proper translation API.
        curl_command = f"curl -s \"https://translate.googleapis.com/translate_a/single?client=gtx&sl=ja&tl=en&dt=t&q={encoded_phrase}\""
        try:
            result = subprocess.run(curl_command, shell=True, capture_output=True, text=True, check=True).stdout
            json_data = json.loads(result)
            part = json_data[0][0][0] if json_data and json_data[0] else "[Untranslated]"
        except (subprocess.CalledProcessError, json.JSONDecodeError):
            part = "[Untranslated]"
        translation.append(part)
    return " ".join(translation).strip()
