from googletrans import Translator

def translate_readme(input_text, target_lang):
    translator = Translator()
    translated = translator.translate(input_text, dest=target_lang)
    translated_text = translated.text
    
    # add hint for automatically translation
    translated_text = f"This is an automatically translated file. Original content in [German](https://github.com/tuxbox-neutrino/buildenv/blob/3.2.4/README-de.md):\n\n{translated_text}"

    # replace [Build Image](#Build-Image) with [Build Image](#build-image), Use this workaround, because translater breaks this anchor 
    translated_text = translated_text.replace("[Build Image](#Build Image)", "[Build Image](#build-image)")
    
    # fix broken links
    translated_text = translated_text.replace("devtool -reference.html", "devtool-reference.html")
    translated_text = translated_text.replace("dev-manual -common-tasks.html", "dev-manual-common-tasks.html")

    return translated_text

if __name__ == "__main__":
    input_text = open("README-de.md", "r").read()
    target_lang = "en"  # target language is english
    translated_text = translate_readme(input_text, target_lang)

    with open("README-en.md", "w") as outfile:
        outfile.write(translated_text)



