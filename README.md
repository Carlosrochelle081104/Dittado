# Dittado

> **Ditado por voz nativo, inteligente e 100% offline para macOS (Apple Silicon).**

O **Dittado** é um aplicativo de barra de menus para macOS que permite ditar textos com alta precisão (frases curtas costumam ficar prontas em cerca de 1,5 a 2 s depois de soltar a tecla, no nosso Mac de teste) em qualquer aplicativo (WhatsApp, Slack, Obsidian, Chrome, Mail, Xcode, etc.). 

Diferente de soluções convencionais baseadas em nuvem, o Dittado processa **todo o áudio e texto localmente no seu Mac**, utilizando aceleração por hardware via Metal com **Whisper** e **LLM Qwen2.5**.

<!-- TODO: screenshot do painel principal do Dittado -->

---

## ⚡ Destaques

- **100% Local e Privado:** Nenhum byte de áudio ou texto sai da sua máquina. Zero servidores na nuvem, zero assinaturas e zero telemetria.
- **Inserção Direta no Cursor:** Pressione o atalho global e fale. Ao soltar, o texto é automaticamente pontuado e colado onde você estiver digitando.
- **Dois Modos de Ditado:**
  - **Modo Livre:** Transcrição rápida, fiel à sua fala, com pontuação automática, comandos de parágrafo por voz (*"novo parágrafo"*, *"pula linha"*) e listas numeradas automáticas.
  - **Modo Profissional:** Organiza o texto como um e-mail ou mensagem corporativa polida, com parágrafos claros, saudação natural e fechamento único, sem inventar fatos ou dados.
- **Reconhecimento Inteligente de Enumerações:** Fale *"primeiro memória RAM segundo lâmpada terceiro fogão"* e veja o texto se transformar automaticamente em uma lista numerada `1. 2. 3.` linha a linha.
- **Vocabulário Personalizado:** Ensine termos técnicos, nomes próprios de projetos ou empresas para evitar correções indesejadas.
- **Leve e Adaptado ao seu Hardware:** Recomenda automaticamente modelos conforme a memória RAM do seu Mac (1.5B para 8 GB; 7B para 16 GB+).

---

## 🎙️ Modos de Ditado & Exemplos Reais

### 1. Modo Livre (Atalho padrão: segurar `Fn`)
Ideal para anotações, mensagens de chat e rascunhos rápidos. Pontua frases, respeita o ritmo da sua fala e formata listas numeradas instantaneamente. No comportamento padrão (*automático*), basta segurar a tecla `Fn` enquanto fala e soltá-la para colar (ou dar um toque rápido para travar a gravação).

**Exemplo de fala:**
> *"Quero comprar 5 itens para minha lista. Primeiro, memória RAM. Segundo, lâmpada. Terceiro, fogão. Quarto, TV de 53 polegadas. Quinto, corda."*

**Resultado colado:**
```text
Quero comprar 5 itens para minha lista:
1. Memória RAM
2. Lâmpada
3. Fogão
4. TV de 53 polegadas
5. Corda
```

### 2. Modo Profissional (Atalho padrão: segurar `Fn + Shift`)
Ideal para e-mails e comunicação corporativa. Remove vícios de linguagem (*"né"*, *"tipo assim"*, *"hum"*), organiza o corpo em parágrafos executivos e gera saudações e despedidas naturais. Proibido de alucinar ou inventar campos de cabeçalho (`Para:` ou `Assunto:`).

**Exemplo de fala:**
> *"para o fornecedor assunto formalização da compra do item 345 bom dia segue o e-mail formalizando a compra do item 345 do orçamento 53 obrigado"*

**Resultado colado (saída real medida no benchmark):**
```text
Bom dia,

Segue o e-mail formalizando a compra do item 345 do orçamento 53.

Obrigado.
```

---

## 💻 Requisitos do Sistema

- **Arquitetura:** Apple Silicon (chips M1, M2, M3, M4 ou superiores).
- **Sistema Operacional:** macOS 14.0 (Sonoma) ou superior.
- **Memória RAM:**
  - **8 GB a 15 GB de RAM:** Utiliza o modelo leve **Qwen2.5 1.5B Instruct** (~986 MB em disco, uso de RAM ainda não medido, latência do formatador de 0,5 s a 1,5 s em testes).
  - **16 GB ou mais de RAM:** Utiliza o modelo de alta fidelidade **Qwen2.5 7B Instruct** (~4,68 GB em disco, ~5,2 GB de RAM ativa com KV cache em Metal, latência de 1,3 s a 2,5 s em e-mails).
  - **Opção Sem LLM:** Opera exclusivamente com o Whisper + regras determinísticas (zero consumo adicional de memória para LLM).
- **Armazenamento:**
  - Whisper large-v3-turbo (Q8_0): ~874 MB.
  - Qwen2.5 1.5B Instruct (Q4_K_M): ~986 MB (para Macs de 8 GB).
  - Qwen2.5 7B Instruct (Q4_K_M): ~4,68 GB (para Macs de 16 GB+).

---

## 🚀 Instalação

### Opção 1: Baixar a Release (Recomendado)
1. Acesse a aba de [Releases](https://github.com/Carlosrochelle081104/Dittado/releases).
2. Baixe o arquivo `Dittado-macOS-arm64.zip`.
3. Descompacte o arquivo e arraste o `Dittado.app` para a sua pasta `/Applications` (Aplicativos).
4. Abra o aplicativo.

#### ⚠️ Aviso do macOS Gatekeeper (Aplicativo sem Notarização)
Como o Dittado é um projeto de código aberto distribuído gratuitamente e de forma independente (sem uma conta paga anual de $99/ano no Apple Developer Program), o macOS exibirá na primeira abertura um aviso informando que o desenvolvedor não pôde ser verificado.

**Para liberar a execução (basta uma única vez):**
1. **Método 1 (Mais simples):** Clique com o **botão direito** no `Dittado.app` dentro de `/Applications` e selecione **Abrir**. Na janela de diálogo que surgir, clique em **Abrir**.
2. **Método 2 (Ajustes):** Acesse **Ajustes do Sistema** > **Privacidade e Segurança** > role até a seção **Segurança** e clique no botão **"Abrir Mesmo Assim"**.
3. **Método 3 (Terminal):** Se preferir linha de comando, execute:
   ```bash
   xattr -dr com.apple.quarantine /Applications/Dittado.app
   ```

---

### Opção 2: Compilar a partir do Código-Fonte
Requisitos: macOS com Command Line Tools instalado (`xcode-select --install`).

```bash
# 1. Clone o repositório
git clone https://github.com/Carlosrochelle081104/Dittado.git
cd Dittado

# 2. Baixe os frameworks nativos pré-compilados (whisper.cpp e llama.cpp)
./scripts/baixar-dependencias.sh --sem-modelos

# 3. Compile e empacote o aplicativo (gera build/Dittado.app)
./scripts/build.sh --sem-instalar

# 4. Mova para a pasta Aplicativos
cp -R build/Dittado.app /Applications/
```

---

## 🔒 Permissões do Sistema

O Dittado solicita 3 permissões padrão do macOS para poder operar:
1. **Microfone:** Necessário para capturar o áudio da sua voz enquanto a tecla de atalho é acionada.
2. **Acessibilidade:** Necessário para simular a colagem/digitação do texto transcrito diretamente no cursor do aplicativo em foco.
3. **Monitoramento de Entrada:** Necessário para reconhecer o atalho global de teclado (por padrão: segurar a tecla `Fn`/Globo) mesmo com outros aplicativos ativos.

> **Dica:** O assistente de configuração inicial (Onboarding) orienta a concessão dessas permissões e possui atalhos diretos para os painéis de Ajustes do Sistema. Caso conceda o Monitoramento de Entrada, encerre e reabra o aplicativo uma vez para que o macOS aplique a mudança.

---

## 🛡️ Privacidade por Concepção

- **Zero Chamadas de Rede em Execução:** Durante a transcrição e uso diário, o aplicativo não efetua nenhuma requisição de rede.
- **Download sob Demanda:** A única comunicação de rede existe no assistente de primeiro uso ou no gerenciador de modelos, exclusivamente para baixar os arquivos de modelos de IA diretamente dos repositórios oficiais da Hugging Face.
- **Logs Seguros:** Por padrão, o log local (`~/Library/Application Support/Dittado/dittado.log`) registra apenas timestamps, tempos de resposta e erros operacionais. O texto transcrito **nunca é registrado em disco**, exceto se o usuário habilitar manualmente a opção de depuração no painel.

---

## 📚 Vocabulário Personalizado

Se você usa com frequência nomes de empresas, jargões técnicos ou abreviações (ex.: *PostgreSQL*, *Next.js*, *Kubernetes*, nomes de clientes), abra o painel do Dittado (`Abrir painel…` na barra de menus) e adicione esses termos na seção **Vocabulário**.

Os termos cadastrados alimentam o prompt de contexto do Whisper e do LLM, garantindo grafia exata e sem correções indesejadas.

---

## 🛠️ Solução de Problemas

- **O atalho não inicia a gravação:** Verifique em *Ajustes do Sistema > Privacidade e Segurança > Monitoramento de Entrada* se o Dittado está marcado. Se estiver marcado e não responder, desmarque, marque novamente e reinicie o Dittado.
- **O texto transcrito não é colado:** Verifique se o Dittado tem permissão em *Ajustes do Sistema > Privacidade e Segurança > Acessibilidade*.
- **O microfone gravado está mudo:** Abra o painel do Dittado e confira a opção de *Microfone*. Você pode forçar o uso do *Microfone do Mac* em vez de dispositivos Bluetooth externos.
- **Download do modelo interrompido:** O download suporta retomada automática via HTTP Range. Abra `Configuração inicial…` ou `Gerenciador de modelos…` no menu e clique em **Retomar**.

---

## ⚠️ Limitações Conhecidas

- **Suporte Exclusivo a macOS Apple Silicon:** Não há suporte para Macs Intel antigos ou para Windows/Linux, devido à dependência de Metal e da arquitetura unificada de memória para execução veloz de LLMs locais.
- **Idioma Principal:** As heurísticas determinísticas e prompts de refinamento foram desenvolvidos e calibrados primariamente para o **português do Brasil (pt-BR)**. O Whisper nativamente transcreve em dezenas de idiomas, mas a reescrita estruturada no Modo Profissional foca em pt-BR.

---

## 🗺️ Roadmap

- [ ] Suporte a prompts multilíngues para o Modo Profissional (Inglês e Espanhol).
- [ ] Atalhos configuráveis por aplicativo específico.
- [ ] Detecção automática de idioma falado na transcrição.

---

## 🤝 Como Contribuir

Contribuições são muito bem-vindas! Consulte o arquivo [CONTRIBUTING.md](CONTRIBUTING.md) para diretrizes de desenvolvimento, regras de privacidade e como rodar a suíte unificada de testes.

Por favor, observe também nosso [Código de Conduta](CODE_OF_CONDUCT.md).

---

## 📄 Licença

Distribuído sob a licença **MIT**. Consulte o arquivo [LICENSE](LICENSE) para mais informações.

Para detalhes sobre as licenças de componentes e modelos de terceiros (whisper.cpp, llama.cpp, Qwen), consulte [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
