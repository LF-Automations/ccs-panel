# Painel CCS (Centro de Controle de Sistemas)

O **Painel CCS** é uma suíte unificada de administração e auditoria para sistemas Linux, desenvolvida em Shell Script (Bash). Criado como um projeto de conclusão acadêmica, o sistema centraliza operações críticas de infraestrutura em uma interface interativa de terminal (CLI), unindo a automação de baixo nível com suporte cognitivo via Inteligência Artificial (AIOps).

## Principais Funcionalidades e Módulos

O sistema opera através de 7 módulos principais, mapeados diretamente para conceitos fundamentais de Sistemas Operacionais:

*   **1. Informações do Sistema:** Diagnóstico de hardware e rede cruzando dados de `/etc/os-release`, utilitários de arquitetura (`lscpu`) e chamadas de sistema do núcleo (`uname`).
*   **2. Monitor de Processos:** Leitura da tabela de processos do Kernel, com envio de sinais de interrupção (`SIGTERM` via `killall`) e suporte a auditoria IA para investigar comportamentos suspeitos.
*   **3. Buscador Avançado de Arquivos:** Varredura atômica de diretórios utilizando Inodes e metadados de tempo/tamanho. Aplica a técnica de *batching* de chamadas de sistema (`-exec {} +`) para prevenir sobrecarga de E/S.
*   **4. Backup Local Criptografado:** Pipeline nativo de compressão (`tar`) e aplicação de criptografia simétrica militar AES-256 (`gpg`), garantindo a confidencialidade do volume no disco.
*   **5. Espaço e Gerenciamento de Disco:** Consulta ao espaço lógico através da abstração do Virtual File System (VFS) com `df`, combinada à verificação da topologia de hardware (diferenciação entre SSD e HD mecânico) via `lsblk`.
*   **6. Matriz de Permissões POSIX:** Gerenciador visual para a matriz de Controle de Acesso Discricionário (DAC), reescrevendo bits de permissão (Leitura, Escrita, Execução) diretamente no Inode do arquivo.
*   **7. Auditoria de Logs de Sistema:** Interceptação de eventos binários do daemon `systemd-journald`. Inclui filtragem dinâmica, exportação, envio automático de relatórios via cliente SMTP (TLS) e análise heurística via API.

## Arquitetura e Engenharia de Software

O desenvolvimento deste painel foi estruturado para demonstrar a aplicação prática de arquitetura de sistemas subjacentes:

*   **Comunicação Interprocessos (IPC):** Uso extensivo de *pipes* (`|`) para estabelecer canais de memória, conectando múltiplos processos independentes (como `journalctl`, `grep`, `tail` e `awk`) em um fluxo cooperativo de dados sem gravação temporária em disco.
*   **Integração REST e Parsing:** Implementação de um cliente de rede local via `curl` para integrar a *Interactions API* do Gemini. O script realiza a higienização de lixo binário gerado pelo Kernel e aplica manipulação nativa de *strings* no Bash para tratar cargas JSON de resposta e requisição.
*   **Desacoplamento de Credenciais:** As chaves de acesso não ficam embutidas no código principal, sendo carregadas dinamicamente via arquivo oculto diretamente para a memória do processo, prevenindo vazamentos em sistemas de controle de versão.


## Instalação e Configuração

1. Clone o repositório localmente:
```
git clone git@github.com:LF-Automations/ccs-panel.git
cd ccs-panel
chmod +x ccs.sh
```
2. Configure as Variáveis de Ambiente:
Para que os módulos de notificação (E-mail SMTP) e Auditoria de IA funcionem, crie um ficheiro oculto de credenciais no diretório home do seu utilizador:

```bash
nano ~/.senha.sh
```

Insira as variáveis abaixo com os seus dados:

```bash
MEU_GMAIL="seu_email@gmail.com"
SENHA_APP="sua_senha_de_aplicativo_gerada_no_google"
CHAVE_GEMINI="sua_chave_de_api_do_google_ai_studio"
```

**3. Execução do Painel:**

Inicie a interface executando o script principal:

```bash
./ccs.sh
```

Para visualizar a documentação estrutural embarcada no terminal:

```bash
./ccs.sh -h
```
