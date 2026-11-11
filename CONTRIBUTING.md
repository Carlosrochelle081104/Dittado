# Contribuindo com o Dittado

Obrigado pelo seu interesse em contribuir com o **Dittado**! Como um projeto de código aberto focado em privacidade, buscamos manter o código limpo, auditável e estritamente offline.

---

## 🔒 Regra Inegociável de Privacidade

Antes de escrever qualquer linha de código, tenha em mente a regra fundamental do projeto:

> **O Dittado opera 100% offline.**
> - É terminantemente proibido adicionar telemetria, rastreadores ou bibliotecas que enviem dados pela rede.
> - Nenhum áudio ou texto transcrito jamais deve ser transmitido pela rede ou gravado em arquivos de log sem autorização explícita do usuário.
> - A única exceção de rede do aplicativo é o download manual de modelos oficiais diretamente da Hugging Face no módulo isolado `DownloadModelos.swift`.

---

## 🛠️ Ambiente de Desenvolvimento

### Requisitos
- Computador Mac com Apple Silicon (M1 ou superior).
- macOS 14.0 (Sonoma) ou superior.
- Xcode Command Line Tools instalado (`xcode-select --install`).

### Como Clonar e Compilar
```bash
# 1. Clone o repositório
git clone https://github.com/Carlosrochelle081104/Dittado.git
cd Dittado

# 2. Baixe os frameworks nativos (whisper.cpp e llama.cpp pré-compilados)
./scripts/baixar-dependencias.sh --sem-modelos

# 3. Compile o executável e o bundle .app (em modo release, sem instalar no sistema)
./scripts/build.sh --sem-instalar

# O app compilado estará disponível em build/Dittado.app
```

---

## 🧪 Executando os Testes

O projeto possui uma suíte unificada de testes automatizados determinísticos cobrindo sanitização, comandos de voz, parser de listas, regras de e-mail, vocabulário, recomendação por RAM e validação de download:

```bash
swift run DittadoTeste --testes
```

> **Nota:** A suíte de testes foi projetada para rodar em clone limpo mesmo com a pasta de modelos vazia. Testes de inferência real de modelos são pulados automaticamente quando os arquivos de pesos não estão presentes.

---

## 📐 Estilo e Padrões de Código

- **Swift Moderno:** Compatibilidade total com Swift 6 e Swift 5.10.
- **Sem Dependências Desnecessárias:** O app utiliza bibliotecas de sistema do macOS (AppKit, SwiftUI, AVFoundation, CryptoKit) e os frameworks C/C++ nativos (`whisper.framework` e `llama.framework`). Evite adicionar pacotes SwiftPM de terceiros a menos que estritamente necessário.
- **Nomenclatura Clara:** Siga as diretrizes de design do Swift (Swift API Design Guidelines).
- **Tratamento de Erros:** Não ignore erros silenciosamente; use logs estruturados em `log(...)` para depuração.

---

## 📬 Como Propor Mudanças (Pull Requests)

1. Crie uma branch a partir de `main`:
   ```bash
   git checkout -b minha-melhoria
   ```
2. Faça alterações pequenas, focadas e bem documentadas.
3. Certifique-se de que a suíte de testes passa 100%:
   ```bash
   swift run DittadoTeste --testes
   ```
4. Se adicionar uma nova funcionalidade determinística (ex.: novas heurísticas de pontuação ou parsing), adicione os respectivos testes na suíte.
5. Abra um Pull Request detalhando o problema resolvido e como testar.
