# Avisos de Terceiros e Licenças (Third-Party Notices)

O **Dittado** utiliza componentes de código aberto e modelos de inteligência artificial de terceiros. Esta página documenta os projetos, licenças e termos aplicáveis a cada componente utilizado.

> **Importante:** Nenhum arquivo binário de modelo de inteligência artificial (`.bin` ou `.gguf`) está versionado ou distribuído diretamente dentro deste repositório Git. Os modelos são baixados sob demanda pelo usuário final no primeiro uso do aplicativo ou via scripts documentados.

---

## 1. Bibliotecas e Motores de Execução (C/C++ / Metal)

### whisper.cpp
- **Descrição:** Motor nativo de inferência para modelos Whisper em C/C++ otimizado com Metal para Apple Silicon.
- **Versão / Tag utilizada:** `b5130`
- **Repositório:** [https://github.com/ggml-org/whisper.cpp](https://github.com/ggml-org/whisper.cpp)
- **Licença:** MIT License
- **Texto da Licença:**
```text
MIT License

Copyright (c) 2023-2024 Georgi Gerganov

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

### llama.cpp / ggml
- **Descrição:** Motor nativo de inferência para Large Language Models (LLMs) em C/C++ com aceleração Metal.
- **Versão / Tag utilizada:** `b12262`
- **Repositório:** [https://github.com/ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp)
- **Licença:** MIT License
- **Texto da Licença:**
```text
MIT License

Copyright (c) 2023-2024 Georgi Gerganov and llama.cpp contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 2. Modelos de Inteligência Artificial

Os modelos a seguir podem ser baixados opcionalmente pelo usuário para execução 100% local no macOS.

### Whisper large-v3-turbo (Q8_0)
- **Autor / Arquitetura Original:** OpenAI
- **Conversão e quantização GGUF/bin:** Georgi Gerganov (`ggerganov/whisper.cpp`)
- **Arquivo:** `ggml-large-v3-turbo-q8_0.bin`
- **Checksum SHA-256:** `317eb69c11673c9de1e1f0d459b253999804ec71ac4c23c17ecf5fbe24e259a1`
- **Repositório:** [https://huggingface.co/ggerganov/whisper.cpp](https://huggingface.co/ggerganov/whisper.cpp)
- **Licença:** MIT License
- **Termos:** Os pesos originais do Whisper foram lançados pela OpenAI sob a licença MIT.

---

### Qwen2.5-7B-Instruct (Q4_K_M)
- **Autor:** Alibaba Cloud / Qwen Team
- **Quantização GGUF:** bartowski (`bartowski/Qwen2.5-7B-Instruct-GGUF`)
- **Arquivo:** `Qwen2.5-7B-Instruct-Q4_K_M.gguf`
- **Checksum SHA-256:** `65b8fcd92af6b4fefa935c625d1ac27ea29dcb6ee14589c55a8f115ceaaa1423`
- **Repositório Original:** [https://huggingface.co/Qwen/Qwen2.5-7B-Instruct](https://huggingface.co/Qwen/Qwen2.5-7B-Instruct)
- **Licença:** Apache License 2.0
- **Texto da Licença:** Disponível em [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

---

### Qwen2.5-1.5B-Instruct (Q4_K_M)
- **Autor:** Alibaba Cloud / Qwen Team
- **Quantização GGUF:** bartowski (`bartowski/Qwen2.5-1.5B-Instruct-GGUF`)
- **Arquivo:** `Qwen2.5-1.5B-Instruct-Q4_K_M.gguf`
- **Checksum SHA-256:** `1adf0b11065d8ad2e8123ea110d1ec956dab4ab038eab665614adba04b6c3370`
- **Repositório Original:** [https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct](https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct)
- **Licença:** Apache License 2.0
- **Texto da Licença:** Disponível em [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).
