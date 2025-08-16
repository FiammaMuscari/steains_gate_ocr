import re
import pykakasi

def convert_to_romaji(text: str) -> str:
    """
    Converts Japanese text to romaji and capitalizes proper nouns specific to Steins;Gate.
    """
    # Clean rare characters, leaving only Japanese
    text = re.sub(r'[^ぁ-んァ-ン一-龯、。！？]', '', text)

    kks = pykakasi.kakasi()
    result = kks.convert(text)

    romaji_list = [item['hepburn'] for item in result]
    romaji = ''.join(romaji_list)

    # Capitalize proper nouns typical of Steins;Gate
    names = ['okabe','rintarou','kurisu','makise','mayuri','shiina','daru','hashida',
             'itaru','suzuha','amane','faris','ruka','urushibara','moeka','kiryuu']
    for name in names:
        romaji = re.sub(r'\b'+name+r'\b', name.capitalize(), romaji, flags=re.IGNORECASE)
            
    return romaji

def correct_ocr_errors(text: str) -> str:
    """
    Applies a series of corrections to common OCR errors in Japanese text.
    """
    text = text.replace('4のと[a-zA-Z]にすらち', 'から')
    text = text.replace('薩られ', 'から')
    text = text.replace('でたよき', 'んでたよ')
    text = text.replace('まゆ!り', 'まゆり')
    text = text.replace('條', '場')
    text = text.replace('一 槍', '一緒')
    text = text.replace('ー一', '一')
    text = text.replace('ロ', '口')
    text = text.replace('力一', 'カー')
    text = text.replace('間ら生生', 'から')
    text = text.replace('笑付いいて', '気付いて')
    text = text.replace('らししな', 'らしいな')
    text = text.replace('話しか', '話しが')
    text = text.replace('いいな', 'いな')
    return text
