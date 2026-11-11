# Dittado

> **Native, smart, and 100% offline voice dictation for macOS (Apple Silicon).**

[Português (Brasil)](README.md) | **English**

**Dittado** is a menu bar application for macOS that enables highly accurate (short phrases are typically ready in about 1.5–2 s after releasing the key on our test Mac) voice dictation into any application (WhatsApp, Slack, Obsidian, Chrome, Mail, Xcode, etc.).

Unlike conventional cloud-based dictation services, Dittado processes **all audio and text entirely on your Mac**, leveraging Metal hardware acceleration with **Whisper** and local **Qwen2.5 LLMs**.

<!-- TODO: screenshot of Dittado main panel -->

---

## ⚡ Highlights

- **100% Local & Private:** Not a single byte of audio or text ever leaves your machine. Zero cloud servers, zero subscriptions, and zero telemetry.
- **Direct Cursor Insertion:** Press the global shortcut and speak. Upon release, your speech is punctuated and pasted straight into your focused text field.
- **Two Tailored Dictation Modes:**
  - **Free Mode:** Quick, faithful transcription with automatic punctuation, spoken paragraph commands (*"new paragraph"*, *"line break"*), and voice-driven numbered lists.
  - **Professional Mode:** Polishes your dictation into an executive-grade email or corporate message with concise paragraphs, natural greetings, and single closings, without hallucinating facts or adding unwanted headers.
- **Smart Voice Enumeration:** Say *"first RAM memory second lamp third stove"* and watch it instantly turn into a cleanly formatted `1. 2. 3.` list item by item.
- **Custom Vocabulary:** Teach Dittado technical jargon, company names, and project terms to prevent awkward autocorrect mistakes.
- **Hardware-Adaptive:** Automatically detects your Mac's RAM and recommends the ideal model (1.5B for 8 GB; 7B for 16 GB+).

---

## 🎙️ Dictation Modes & Real Examples

### 1. Free Mode (Default shortcut: hold `Fn`)
Ideal for quick notes, chat messages, and free-form drafting. Accurately punctuates sentences and automatically parses spoken lists. In default (*automatic*) behavior, simply hold the `Fn` key while speaking and release to paste (or tap once to latch recording).

**Spoken input:**
> *"Quero comprar 5 itens para minha lista. Primeiro, memória RAM. Segundo, lâmpada. Terceiro, fogão. Quarto, TV de 53 polegadas. Quinto, corda."*

**Pasted output:**
```text
Quero comprar 5 itens para minha lista:
1. Memória RAM
2. Lâmpada
3. Fogão
4. TV de 53 polegadas
5. Corda
```

### 2. Professional Mode (Default shortcut: hold `Fn + Shift`)
Ideal for work emails and professional communication. Strips filler sounds, structures clean paragraphs, and ensures a single polite closing without inventing `To:` or `Subject:` fields.

**Spoken input:**
> *"para o fornecedor assunto formalização da compra do item 345 bom dia segue o e-mail formalizando a compra do item 345 do orçamento 53 obrigado"*

**Pasted output (real output measured during benchmark):**
```text
Bom dia,

Segue o e-mail formalizando a compra do item 345 do orçamento 53.

Obrigado.
```

---

## 💻 System Requirements

- **Architecture:** Apple Silicon (M1, M2, M3, M4 or newer).
- **Operating System:** macOS 14.0 (Sonoma) or newer.
- **System Memory (RAM):**
  - **8 GB to 15 GB RAM:** Uses the lightweight **Qwen2.5 1.5B Instruct** (~986 MB on disk, RAM usage not yet measured, formatter latency of 0.5–1.5 s in tests).
  - **16 GB+ RAM:** Uses the full **Qwen2.5 7B Instruct** (~4.68 GB on disk, ~5.2 GB active RAM in Metal with KV cache, ~1.3s–2.5s latency).
  - **No LLM Option:** Operates using only Whisper + deterministic rules (zero extra RAM overhead).
- **Disk Storage:**
  - Whisper large-v3-turbo (Q8_0): ~874 MB.
  - Qwen2.5 1.5B Instruct (Q4_K_M): ~986 MB (recommended for 8 GB Macs).
  - Qwen2.5 7B Instruct (Q4_K_M): ~4.68 GB (recommended for 16 GB+ Macs).

---

## 🚀 Installation

### Option 1: Download Pre-built Release (Recommended)
1. Go to the [Releases](https://github.com/Carlosrochelle081104/Dittado/releases) page.
2. Download `Dittado-macOS-arm64.zip`.
3. Unzip and drag `Dittado.app` into your `/Applications` folder.
4. Launch the application.

#### ⚠️ macOS Gatekeeper Notice (Un-notarized Application)
Because Dittado is an open-source project distributed for free independently (without paying the annual $99 fee for the Apple Developer Program), macOS will show a security prompt stating that the developer cannot be verified on first launch.

**How to open (one-time only):**
1. **Method 1 (Easiest):** Right-click (or Control-click) `Dittado.app` in `/Applications` and select **Open**. In the prompt that appears, click **Open**.
2. **Method 2 (System Settings):** Go to **System Settings** > **Privacy & Security** > scroll to **Security** and click **"Open Anyway"**.
3. **Method 3 (Terminal):**
   ```bash
   xattr -dr com.apple.quarantine /Applications/Dittado.app
   ```

---

### Option 2: Build from Source
Requirements: macOS with Command Line Tools installed (`xcode-select --install`).

```bash
# 1. Clone the repository
git clone https://github.com/Carlosrochelle081104/Dittado.git
cd Dittado

# 2. Download native precompiled frameworks (whisper.cpp and llama.cpp)
./scripts/baixar-dependencias.sh --sem-modelos

# 3. Build and package application bundle (creates build/Dittado.app)
./scripts/build.sh --sem-instalar

# 4. Copy to Applications folder
cp -R build/Dittado.app /Applications/
```

---

## 🔒 System Permissions

Dittado requires 3 standard macOS permissions:
1. **Microphone:** To capture your voice while the hotkey is held.
2. **Accessibility:** To paste transcribed text directly at your current cursor position.
3. **Input Monitoring:** To detect the global shortcut (by default: holding the `Fn`/Globe key) while working in other apps.

> **Tip:** The onboarding wizard guides you through granting these permissions with direct buttons to the relevant System Settings panes. If you grant Input Monitoring, restart the app once for macOS to apply the permission.

---

## 🛡️ Privacy by Design

- **Zero Runtime Network Calls:** The app makes zero network connections during dictation and normal operation.
- **On-Demand Downloads Only:** Network traffic only occurs if you explicitly choose to download AI models during the onboarding or from the Model Manager, connecting directly to official Hugging Face repositories.
- **Safe Logging:** By default, local logs (`~/Library/Application Support/Dittado/dittado.log`) record only timestamps, latencies, and operational errors. Your spoken text is **never written to disk** unless you explicitly enable debug logging in the panel.

---

## 📚 Custom Vocabulary

If you frequently dictate company names, technical terminology, or abbreviations (e.g., *PostgreSQL*, *Next.js*, *Kubernetes*, client names), open the Dittado panel and add them under **Vocabulary**.

Registered terms are supplied to the Whisper and LLM prompts, ensuring exact spelling without unintended corrections.

---

## 🛠️ Troubleshooting

- **Shortcut does not trigger recording:** Check *System Settings > Privacy & Security > Input Monitoring* to ensure Dittado is enabled. If checked and unresponsive, uncheck, re-check, and restart Dittado.
- **Text does not paste:** Verify that Dittado is enabled under *System Settings > Privacy & Security > Accessibility*.
- **Microphone is silent:** Open the Dittado panel and review your *Microphone* policy. You can choose *MacBook Microphone* instead of external Bluetooth devices.
- **Model download interrupted:** Downloads support HTTP Range resumption. Open `Initial Setup…` or `Model Manager…` from the menu bar and click **Resume**.

---

## ⚠️ Known Limitations

- **Apple Silicon Exclusive:** Intel-based Macs, Windows, and Linux are not supported due to reliance on Metal and Apple Silicon Unified Memory.
- **Primary Language:** Formatting heuristics and system prompts are currently tuned for **Brazilian Portuguese (pt-BR)**. Whisper itself supports multiple languages, but executive re-writing is optimized for pt-BR.

---

## 🗺️ Roadmap

- [ ] Multi-language prompt support for Professional Mode (English, Spanish).
- [ ] Per-app custom shortcut configuration.
- [ ] Automatic spoken language detection.

---

## 🤝 Contributing

Contributions are welcome! Please check [CONTRIBUTING.md](CONTRIBUTING.md) for coding guidelines, privacy rules, and test suite execution.

Please also adhere to our [Code of Conduct](CODE_OF_CONDUCT.md).

---

## 📄 License

Distributed under the **MIT** License. See [LICENSE](LICENSE) for details.

For third-party components and AI model licenses (whisper.cpp, llama.cpp, Qwen), see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
