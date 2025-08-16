import subprocess

def preprocess_image(input_path: str, output_path: str):
    subprocess.run(['convert', input_path, '-resize', '400%', '-colorspace', 'Gray', '-contrast-stretch', '2%x1%',
                    '-normalize', '-sharpen', '0x2', '-threshold', '50%', '-morphology', 'Open', 'Diamond:1', '-despeckle', output_path],
                   capture_output=True)
