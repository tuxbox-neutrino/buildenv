from googletrans import Translator

def translate_readme(input_text, target_lang):
    translator = Translator()
    translated = translator.translate(input_text, dest=target_lang)
    translated_text = translated.text
    
    # add hint for automatically translation
    translated_text = f"Note: This is an automatically translated file. Original content from [here](https://github.com/tuxbox-neutrino/buildenv/blob/3.2.4/README-de.md):\n\n{translated_text}"

    # Use this workaround, because translater breaks some links and anchors
    translated_text = translated_text.replace("[Build Image](#Build Image)", "[Build Image](#build-image)")
    translated_text = translated_text.replace("devtool -reference.html", "devtool-reference.html")
    translated_text = translated_text.replace("dev-manual -common-tasks.html", "dev-manual-common-tasks.html")
    translated_text = translated_text.replace("Clone #1-Init-Script", "#1-clone-init-script")

    return translated_text

if __name__ == "__main__":
    input_text = open("README-de.md", "r").read()
    target_lang = "en"  # target language is english
    translated_text = translate_readme(input_text, target_lang)

    with open("README-en.md", "w") as outfile:
        outfile.write(translated_text)
