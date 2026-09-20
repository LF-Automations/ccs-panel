#!/bin/bash

# ==============================================================================
# PROJETO: CCS (Centro de Controle de Sistemas)
# OBJETIVO: Facilitar o uso do Linux para usuários sem experiência técnica
# ==============================================================================

# Definição de Variáveis Globais de Credenciais
# Na prática de SO e Segurança, o ideal é ler isso de um arquivo externo (ex: ~/.senha.sh),
# mas para fins de demonstração como recomendado, as chaves estão declaradas diretamente na memória do processo.
MEU_GMAIL="@gmail.com"
SENHA_APP=""
CHAVE_GEMINI=""
# Tenta carregar as credenciais do arquivo externo oculto, se ele existir
[ -f "$HOME/.senha.sh" ] && . "$HOME/.senha.sh"

# ================================================================
# MÓDULO 0: MOTOR DE INTELIGÊNCIA ARTIFICIAL (INTERACTIONS API)
# ================================================================
consultar_ia() {
    # 'local' restringe o escopo da variável apenas a esta função. 
    # Conceito de SO: Evita poluição do namespace no ambiente do processo pai (o próprio script).
    local MENSAGEM="$1" 
    
    # 1. VERIFICAÇÃO DE CHAVE DE ACESSO
    # A flag '-z' (zero) testa se a variável está vazia antes de tentar a conexão de rede.
    if [ -z "$CHAVE_GEMINI" ]; then
        echo " [ERRO] Chave da API do Gemini não encontrada."
        echo " Adicione CHAVE_GEMINI='sua_chave' no arquivo ~/.senha.sh"
        return # Interrompe a sub-rotina sem dar 'exit' (que mataria o processo principal).
    fi
    
    echo " ----------------------------------------------------------------"
    echo " [🤖 ANÁLISE GERADA POR INTELIGÊNCIA ARTIFICIAL]"
    echo " Atenção: A IA pode cometer erros ao analisar sistemas complexos."
    echo " Use esta informação apenas como um guia para diagnóstico."
    echo " ----------------------------------------------------------------"
    echo " Consultando a nova Interactions API (Gemini)... aguarde."
    
    # ========================================================================
    # 2. LIMPEZA E HIGIENIZAÇÃO (TRATAMENTO DE I/O)
    # ========================================================================
    local MENSAGEM_CURTA="$MENSAGEM"
    
    # [FOCO: OPÇÃO 7 - LOGS] TRUNCAMENTO
    # Na Opção 2 (Processos), enviamos apenas uma frase curta gerada por nós.
    # Mas na Opção 7, o 'journalctl' pode despejar milhares de linhas de log do Kernel.
    # Esse 'if' garante que, se for um log gigante, pegamos apenas os últimos 1000 caracteres,
    # economizando banda de rede e respeitando o limite do payload da API.
    if [ "${#MENSAGEM}" -gt 1000 ]; then
        MENSAGEM_CURTA="${MENSAGEM: -1000}" 
    fi
    
    # [FOCO: OPÇÃO 7 - LOGS] SANITIZAÇÃO DE LIXO BINÁRIO DO KERNEL
    # Na Opção 2, o texto é limpo. Na Opção 7, os daemons do sistema podem injetar 
    # caracteres ANSI (cores) ou lixo de memória travada direto no log. 
    # O comando 'tr -cd' deleta tudo que não for texto imprimível ASCII ([:print:]), \n ou \t.
    # Sem isso, um log corrompido destruiria a estrutura do nosso pacote JSON.
    MENSAGEM_CURTA=$(echo "$MENSAGEM_CURTA" | tr -cd '[:print:]\n\t')
    
    # [FOCO: OPÇÕES 2 E 7] ESCAPAMENTO DE CARACTERES PARA JSON
    # Expansões nativas do Bash (Find & Replace). 
    # Troca barras, aspas duplas e quebras de linha reais pelas versões escapadas (ex: " vira \").
    # Fundamental para a Opção 7, pois logs frequentemente contêm aspas que fechariam o JSON precocemente.
    local MENSAGEM_LIMPA="${MENSAGEM_CURTA//\\/\\\\}"
    MENSAGEM_LIMPA="${MENSAGEM_LIMPA//\"/\\\"}"
    MENSAGEM_LIMPA="${MENSAGEM_LIMPA//$'\r'/}"
    MENSAGEM_LIMPA="${MENSAGEM_LIMPA//$'\t'/\\t}"
    MENSAGEM_LIMPA="${MENSAGEM_LIMPA//$'\n'/\\n}"

    if [ -z "$MENSAGEM_LIMPA" ]; then
        echo " [ERRO] Mensagem vazia — nada para enviar a IA."
        return
    fi
    #Apresenta erro o de baixo
    # 3. MONTAGEM DO PAYLOAD (ESTRUTURA DE DADOS)
    # Empacota a string que sanitizamos na estrutura JSON exata que o Google exige.
    #local PAYLOAD="{\"model\": \"gemini-3.6-flash\", \"input\": [ { \"type\": \"text\", \"text\": \"$MENSAGEM_LIMPA\" } ] }"
    #local URL="https://generativelanguage.googleapis.com/v1beta/interactions"
    
    # 3. MONTAGEM DO PAYLOAD (ESTRUTURA DE DADOS)
    local PAYLOAD="{\"contents\": [{\"parts\": [{\"text\": \"$MENSAGEM_LIMPA\"}]}]}"
    local URL="https://generativelanguage.googleapis.com/v1/models/gemini-3.6-flash:generateContent"

    # 4. DISPARO DA REQUISIÇÃO DE REDE
    # Utiliza o 'curl' para abrir um socket e enviar um POST HTTP.
    # '-s' oculta a barra de progresso, '-m 30' define um timeout (evita que o processo fique preso indefinidamente).
    local RESPOSTA=$(curl -4 -s -m 30 -X POST "$URL" \
        -H "Content-Type: application/json" \
        -H "x-goog-api-key: $CHAVE_GEMINI" \
        -d "$PAYLOAD")

    # 5. TRATAMENTO DE ERROS DO GOOGLE
    # Usa o 'grep' para procurar a chave "error" na resposta do servidor.
    # Se a conexão for recusada, isola o motivo do erro para o usuário não ficar cego.
    if echo "$RESPOSTA" | grep -q '"error"'; then
        echo " [ERRO] O Google recusou a conexão. O servidor retornou:"
        echo "$RESPOSTA" | tr -d '\n' | grep -oE '"message"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 | sed -E 's/.*"message"[[:space:]]*:[[:space:]]*"//; s/"$//'
        return
    fi

    # 6. EXTRATOR DA RESPOSTA (PARSING NATIVO DO BASH)
    # Remove quebras de linha temporariamente para tratar a resposta inteira como uma linha única.
    local RESPOSTA_PLANA=$(echo "$RESPOSTA" | tr -d '\n')

    # [FOCO: FILTRO DE ECO DA OPÇÃO 7]
    # O 'tail -n 1' é crucial aqui. Na Opção 7, o log enviado é tão grande que o Google
    # costuma enviar um "eco" (repetir a sua pergunta) antes de dar a resposta. 
    # O tail garante que vamos pegar o ÚLTIMO campo "text" do JSON (a resposta real da IA).
    local TEXTO_IA=$(echo "$RESPOSTA_PLANA" | grep -oE '"text"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' | tail -n 1 | sed -E 's/^"text"[[:space:]]*:[[:space:]]*"//; s/"$//')

    if [ -z "$TEXTO_IA" ]; then
        # Fallback de segurança caso o Google mude a chave de "text" para "output_text" na API.
        TEXTO_IA=$(echo "$RESPOSTA_PLANA" | grep -oE '"output_text"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' | head -n 1 | sed -E 's/^"output_text"[[:space:]]*:[[:space:]]*"//; s/"$//')
    fi

    if [ -z "$TEXTO_IA" ]; then
        echo " [ERRO] Não foi possível extrair o texto da resposta. Resposta bruta:"
        echo "$RESPOSTA"
        return
    fi

    # 7. RESTAURAÇÃO DE FORMATAÇÃO (DISPLAY NO TERMINAL)
    # Reverte as quebras de linha virtuais (\n) para quebras reais do terminal
    # para que o usuário leia um texto formatado e bonito, e não um bloco de código.
    TEXTO_IA="${TEXTO_IA//\\n/$'\n'}"
    TEXTO_IA="${TEXTO_IA//\\\"/\"}"
    TEXTO_IA="${TEXTO_IA//\\\\/\\}"

    echo ""
    echo " 💡 $TEXTO_IA"
    echo ""
}
# MÓDULO DE INTERFACE: PAINEL DE AJUDA
# Encapsular isso em uma função (mostrar_help) aplica o conceito de Modularização,
# tirando a poluição visual do fluxo principal (Main) do programa.
# ==============================================================================
mostrar_help() {
    # Loop infinito (Event Loop): Mantém a thread do menu presa aqui dentro.
    # O SO continuará redesenhando o menu na tela até que uma condição de saída seja acionada.
    while true; do
        
        # 'clear' envia uma sequência de controle para o terminal emulator limpar o buffer visual.
        clear 
        
        # O comando 'echo' escreve blocos de texto no Standard Output.
        echo "================================================================"
        echo "                    CCS - CENTRAL DE AJUDA"
        echo "================================================================"
        echo " 1 - Informações do sistema  | 5 - Espaço em disco"
        echo " 2 - Monitor de processos    | 6 - Permissões"
        echo " 3 - Encontrar um arquivo    | 7 - Logs do sistema"
        echo " 4 - Backup                  | 8 - Voltar"
        echo "================================================================"
        
        # I/O BLOQUEANTE (Blocking I/O): 
        # A flag '-p' (prompt) imprime a mensagem, mas o 'read' suspende a execução do script.
        # O processo "dorme" enquanto escuta o teclado (Standard Input - stdin - Descritor 0).
        # Assim que o usuário aperta [ENTER], o SO acorda o processo e salva o dado na variável OP_HELP.
        read -p " Digite o número da opção desejada: " OP_HELP

        # Estrutura de Roteamento (equivalente ao 'switch/case' em linguagens como C ou Java).
        # Compara a variável OP_HELP com os padrões de execução.
        case "$OP_HELP" in
            1) 
                echo " [AJUDA: 1 - INFORMAÇÕES DO SISTEMA]"
                echo " Objetivo: Exibir um diagnóstico rápido do hardware e da rede."
                echo " Como funciona: Consulta as estruturas do Kernel Linux (via comando uname)"
                echo " e os arquivos de configuração do SO (como /etc/os-release). Também aciona"
                echo " ferramentas como 'lscpu' para ler a arquitetura do processador e utilitários"
                echo " de rede (ip e curl) para identificar o IP local e a placa de rede."
                echo "----------------------------------------------------------------"
                read -p " Pressione [ENTER] para voltar..."
                ;;
            2) 
                echo " [AJUDA: 2 - MONITOR DE PROCESSOS]"
                echo " Objetivo: Analisar os programas em execução e o consumo de recursos."
                echo " Como funciona: Lê a tabela de processos atrelados ao Kernel utilizando o"
                echo " utilitário 'ps' e formata a saída com 'awk'. Permite enviar sinais de"
                echo " encerramento (SIGTERM via killall) para interromper processos indesejados,"
                echo " além de contar com integração de Inteligência Artificial para auditar um"
                echo " processo que o usuário considere suspeito."
                echo "----------------------------------------------------------------"
                read -p " Pressione [ENTER] para voltar..."
                ;;
            3) 
                echo " [AJUDA: 3 - ENCONTRAR UM ARQUIVO]"
                echo " Objetivo: Localizar arquivos perdidos, gigantes ou modificados recentemente."
                echo " Como funciona: Utiliza o utilitário nativo 'find', que faz chamadas de sistema"
                echo " de leitura de diretórios (opendir/readdir) para varrer a árvore de arquivos"
                echo " do usuário, filtrando por nome, tamanho (megabytes) ou metadados de tempo"
                echo " contidos nos 'inodes' dos arquivos."
                echo "----------------------------------------------------------------"
                read -p " Pressione [ENTER] para voltar..."
                ;;
            4) 
                echo " [AJUDA: 4 - BACKUP LOCAL CRIPTOGRAFADO]"
                echo " Objetivo: Criar cópias de segurança de pastas de forma altamente segura."
                echo " Como funciona: Primeiro, usa o 'tar' para unificar e comprimir todos os arquivos"
                echo " em um único pacote (.tar.gz). Depois, utiliza o GNU Privacy Guard (GPG) para"
                echo " aplicar uma criptografia simétrica militar (AES-256), exigindo uma senha forte."
                echo " Apenas quem possui a senha pode extrair os dados."
                echo "----------------------------------------------------------------"
                read -p " Pressione [ENTER] para voltar..."
                ;;
            5) 
                echo " [AJUDA: 5 - ESPAÇO EM DISCO]"
                echo " Objetivo: Monitorar o armazenamento e identificar o tipo de disco."
                echo " Como funciona: Utiliza o comando 'lsblk' para ler as informações nos barramentos"
                echo " físicos, identificando se a unidade é um SSD rápido ou um HD mecânico."
                echo " Em seguida, usa o 'df' para calcular o total de blocos livres e em uso"
                echo " na partição principal do sistema."
                echo "----------------------------------------------------------------"
                read -p " Pressione [ENTER] para voltar..."
                ;;
            6) 
                echo " [AJUDA: 6 - PERMISSÕES]"
                echo " Objetivo: Proteger ou liberar o acesso a arquivos e diretórios."
                echo " Como funciona: Funciona como um assistente visual para o comando 'chmod'."
                echo " Ele mapeia as respostas do usuário para construir a matriz de segurança POSIX,"
                echo " manipulando os bits de Leitura (r), Escrita (w) e Execução (x) para o"
                echo " Dono, o Grupo ou para Todos os usuários do sistema."
                echo "----------------------------------------------------------------"
                read -p " Pressione [ENTER] para voltar..."
                ;;
            7) 
                echo " [AJUDA: 7 - LOGS DO SISTEMA]"
                echo " Objetivo: Ler o histórico de eventos, erros e atividades da máquina."
                echo " Como funciona: Conecta-se ao 'journalctl' (diário do systemd) para extrair os"
                echo " logs do boot atual. O módulo conta com filtros avançados, opções para gerar"
                echo " relatórios em formato .txt e até uma rotina SMTP nativa (via curl) para"
                echo " empacotar e despachar os relatórios por e-mail, além de análise de IA."
                echo "----------------------------------------------------------------"
                read -p " Pressione [ENTER] para voltar..."
                ;;
            8) 
                # Quebra o laço 'while true' e retorna para o menu inicial do script
                break 
                ;; 
            *) 
                # Fallback: Captura qualquer digitação que não seja de 1 a 8
                echo " [ERRO] Opção de ajuda não encontrada!"
                read -p " Pressione [ENTER] para tentar novamente..."
                ;;
                
        esac
    done
}
# ================================================================
# MÓDULOS DE FUNCIONALIDADE (CAPÍTULOS DO SISTEMA)
# ================================================================

menu_informacoes() {
    echo "[+] RESUMO DO COMPUTADOR:"
    echo " ----------------------------------------------------------------"
    
    # [CONCEITO DE SO: ARQUIVOS DE CONFIGURAÇÃO E REDIRECIONAMENTO DE I/O]
    # Faz o parse (source) do arquivo release do SO para extrair variáveis nativas como $PRETTY_NAME.
    # O '2>/dev/null' redireciona o descritor de erro (stderr - Descritor 2) para o "buraco negro" do Linux,
    # garantindo que, se o arquivo não existir, o erro não suje a tela do usuário.
    . /etc/os-release 2>/dev/null 
    
    # [CONCEITO DE SO: PIPES E ABSTRAÇÃO DE HARDWARE]
    # 'lscpu' lê as estruturas de hardware do processador (lendo arquivos do subsistema /sys).
    # 'LANG=C' força a execução em inglês puro, evitando que o grep falhe se o sistema do usuário estiver em português.
    # O Pipe (|) atua como um canal de comunicação IPC, passando a saída do lscpu para o grep, e depois para o sed.
    NOME_CPU=$(LANG=C lscpu | grep "Model name:" | sed 's/Model name: *//')
    
    # [CONCEITO DE SO: SYSTEM CALLS]
    # 'uname' é um utilitário que executa a chamada de sistema uname(2) no Kernel
    # para extrair informações da versão e release (-r) do núcleo do sistema operacional.
    VERSAO_KERNEL=$(uname -r)
    
    # [CONCEITO DE SO: PILHA DE REDE (TCP/IP)]
    # Busca a interface de rede ativa. O 'awk' atua processando o texto para imprimir 
    # apenas a primeira coluna de dados ($1), isolando o IP local e descartando IPs secundários (como IPv6 ou Docker).
    IP_LOCAL=$(hostname -I | awk '{print $1}')
    
    # [CONCEITO DE SO: PSEUDO-SISTEMA DE ARQUIVOS]
    # 'uptime' consulta indiretamente o arquivo /proc/uptime gerado dinamicamente pelo Kernel 
    # para saber há quanto tempo a máquina está rodando, usando o 'sed' para traduzir a saída para português.
    TEMPO_ON=$(uptime -p | sed 's/up //; s/hours/horas/; s/minutes/minutos/; s/hour/hora/; s/minute/minuto/; s/days/dias/; s/day/dia/')
    
    echo " 👤 Usuário Logado   : $USER"
    echo " 💻 Sistema (OS)     : $PRETTY_NAME"
    echo " ⚙️ Versão do Kernel  : $VERSAO_KERNEL"
    echo " 🧠 Processador      : $NOME_CPU"
    
    # [TRUQUE DO BASH: EXPANSÃO DE PARÂMETROS]
    # A sintaxe ':-' avisa o Bash: "Se a variável IP_LOCAL estiver vazia (sem rede), exiba a palavra 'Desconectado'".
    echo " 🌐 IP Local (Rede)  : ${IP_LOCAL:-Desconectado}"
    echo " ⏳ Tempo Ligado     : $TEMPO_ON"
    
    # [CONCEITO DE SO: CAMADA DE ENLACE DE DADOS]
    # O 'ip link show' lê os endereços físicos (MAC) atrelados as interfaces de rede da máquina.
    # O 'head -n 1' garante que pegaremos apenas a primeira placa de rede física listada.
    MAC=$(ip link show | awk '/ether/ {print $2}' | head -n 1)
    
    # [CONCEITO DE SO: CURTO-CIRCUITO LÓGICO]
    # Fazemos uma requisição a API usando curl. 
    # O operador '||' (OR Lógico) significa: "Se o comando curl falhar (Exit status diferente de 0),
    # assuma o comando do outro lado". Se o usuário estiver sem internet, a variável recebe "Desconhecido" em vez de quebrar.
    FABRICANTE=$(curl -m 5 -s "https://api.macvendors.com/$MAC" || echo "Desconhecido")
    echo " 🔌 Placa de Rede    : $FABRICANTE"
}
menu_processos() {
    echo "[+] MONITOR DE PROCESSOS:"
    read -p " Quantos programas deseja analisar? (Aperte ENTER para 10): " QTD_PROC
    # Se a variável estiver vazia, define um valor padrão de 10.
    [ -z "$QTD_PROC" ] && QTD_PROC=10 
    
    # 'free' lê os dados de /proc/meminfo para mostrar o status da memória RAM
    MEM_TOTAL=$(free -m | grep "Mem" | awk '{print $2}')
    MEM_USADA=$(free -m | grep "Mem" | awk '{print $3}')
    
    echo " ----------------------------------------------------------------"
    echo " Memória RAM Total: ${MEM_TOTAL} MB | Memória em Uso: ${MEM_USADA} MB"
    echo " ----------------------------------------------------------------"
    printf " %-25s | %-10s | %-10s\n" "NOME DO PROGRAMA" "USO DA CPU" "USO DA RAM"
    echo " --------------------------|------------|------------"
    
    # Lê a tabela de processos atrelados ao kernel ('ps'), ordena por CPU (--sort=-%cpu) 
    # e envia o resultado (via pipe '|') para o awk formatar em colunas padronizadas.
    ps -eo comm,%cpu,%mem --sort=-%cpu --no-headers | grep -v -w "ps" | grep -v -w "awk" | head -n "$QTD_PROC" 2>/dev/null | awk '{printf " %-25s | %-10s | %-10s\n", $1, $2"%", $3"%"}'
    
    echo " ----------------------------------------------------------------"
    echo " O que deseja fazer?"
    echo " [1] Encerrar um programa (Matar processo)"
    echo " [2] Pedir para a IA auditar/explicar um programa"
    echo " [3] Voltar ao menu"
    read -p " Escolha: " OP_PROC
    
    if [ "$OP_PROC" == "1" ]; then
        read -p " Digite o NOME EXATO do programa: " NOME_MATAR
        # killall envia um sinal do Kernel (SIGTERM por padrão) para matar processos vinculados a esse nome.
        killall "$NOME_MATAR" 2>/dev/null && echo " [OK] '$NOME_MATAR' encerrado." || echo " [ERRO] Falha ao encerrar."
    elif [ "$OP_PROC" == "2" ]; then
        read -p " Digite o nome do processo que achou suspeito: " NOME_AUDITAR
        PROMPT="Você é um engenheiro de sistemas Linux. O usuário leigo encontrou um processo chamado '${NOME_AUDITAR}' consumindo recursos da máquina. Explique em duas frases curtas o que é esse programa, para que serve e diga se é seguro forçar o encerramento dele. NUNCA forneça comandos para o usuário rodar no terminal."
        consultar_ia "$PROMPT"
    fi
}

menu_arquivos() {
    echo "[+] BUSCADOR AVANÇADO DE ARQUIVOS:"
    echo " ----------------------------------------------------------------"
    echo " [1] Buscar por NOME"
    echo " [2] Arquivos GIGANTES"
    echo " [3] Arquivos RECENTES"
    read -p " Escolha o tipo de busca (1, 2 ou 3): " OP_BUSCA
    echo " ----------------------------------------------------------------"
    
    # [CONCEITO DE SO: ESTRUTURA DE CONTROLE]
    # Uma estrutura condicional que atua como Switch/Case para rotear a execução do processo.
    case "$OP_BUSCA" in
        1)
            read -p " Qual o nome (ou parte do nome)? " NOME_ARQ
            
            # [CONCEITO DE SO: VARREDURA DE DIRETÓRIOS, OTIMIZAÇÃO DE PROCESSOS E IPC]
            # O 'find' usa chamadas de sistema (opendir/readdir) para buscar intensamente no disco.
            # O '-type f' restringe a busca apenas a "arquivos regulares" (ignorando pastas, links simbólicos e sockets).
            # O '-exec ... {} +' é uma otimização de SO vital: em vez de fazer um fork() para cada arquivo achado,
            # ele agrupa os arquivos e faz poucas chamadas de sistema, passando todos de uma vez para o 'du'.
            # O 'du' (Disk Usage) verifica o espaço real em blocos alocados no disco rígido.
            # O '2>/dev/null' descarta erros de permissão redirecionando o stderr para o dispositivo nulo.
            # O pipe '|' cria um canal de comunicação (IPC) transferindo os dados para o loop 'while' em um subshell.
            find ~ -type f -iname "*$NOME_ARQ*" -exec du -sh {} + 2>/dev/null | while read -r TAMANHO ARQUIVO; do
                printf " 📄 %-7s | %s\n" "$TAMANHO" "$ARQUIVO"
            done
            ;;
        2)
            read -p " Tamanho mínimo em Megabytes? (ENTER p/ 500): " TAM_MIN
            
            # [CONCEITO DE SO: AVALIAÇÃO DE CURTO-CIRCUITO LÓGICO]
            # Se a variável estiver vazia (usuário só deu Enter), define um valor padrão dinamicamente na memória.
            [ -z "$TAM_MIN" ] && TAM_MIN=500
            
            # [CONCEITO DE SO: FILTRO DE METADADOS E PIPELINE MÚLTIPLO]
            # O '-size' não lê o conteúdo do arquivo, ele lê apenas a tabela de metadados do sistema de arquivos.
            # Aqui temos um Pipeline Duplo (find -> sort -> while). 
            # São três processos distintos rodando paralelamente no SO e trocando dados via buffers de memória do Kernel.
            find ~ -type f -size "+${TAM_MIN}M" -exec du -sh {} + 2>/dev/null | sort -hr | while read -r TAMANHO ARQUIVO; do
                printf " 🚨 %-7s | %s\n" "$TAMANHO" "$ARQUIVO"
            done
            ;;
        3)
            read -p " Arquivos das últimas quantas horas? (ENTER p/ 24): " TEMPO_HORAS
            [ -z "$TEMPO_HORAS" ] && TEMPO_HORAS=24
            
            # [CONCEITO DE SO: EXPANSÃO ARITMÉTICA]
            # O Bash delega o cálculo matemático para a Unidade Lógica e Aritmética (ULA) do processador.
            MINUTOS=$(( TEMPO_HORAS * 60 ))
            
            # [CONCEITO DE SO: INODES E TIMESTAMPS]
            # O parâmetro '-mmin' (Modification Minutes) pesquisa pelos metadados de modificação ('mtime').
            # Essa informação de data/hora não fica dentro do arquivo, mas sim salva no 'Inode' do arquivo.
            # O '-exec ls -lh' formata a leitura desse Inode, extraindo dono, grupo, tamanho, data e hora.
            find ~ -type f -mmin "-${MINUTOS}" -exec ls -lh --time-style=+"%d/%m/%Y %H:%M:%S" {} + 2>/dev/null | while read -r PERM LINKS DONO GRUPO TAM DATA HORA ARQUIVO; do
                printf " 🕒 %-7s | 📅 %s às %s | 📄 %s\n" "$TAM" "$DATA" "$HORA" "$ARQUIVO"
            done
            ;;
        *) echo " [ERRO] Opção inválida." ;;
    esac
}
menu_backup() {
    echo "[+] CÓPIA DE SEGURANÇA (BACKUP LOCAL CRIPTOGRAFADO):"
    read -p " Digite o caminho da pasta (Ex: ~/Documentos/): " PASTA_ORIGEM
    
    # [CONCEITO DE SO: VARIÁVEIS DE AMBIENTE E CAMINHOS ABSOLUTOS]
    # O SO trabalha de forma mais segura com caminhos absolutos no VFS (Virtual File System).
    # Aqui fazemos a expansão de string nativa no Bash para trocar o caractere especial '~' 
    # pelo valor real do diretório home do usuário logado (armazenado na variável de ambiente $HOME).
    PASTA_ORIGEM="${PASTA_ORIGEM/#\~/$HOME}" 
    
    # [CONCEITO DE SO: CHAMADAS DE SISTEMA DE ARQUIVOS (SYSCALLS)]
    # Verifica a existência do diretório. Por baixo dos panos, o Bash executa uma chamada
    # de sistema 'stat()' para consultar a tabela de Inodes e verificar se o caminho existe
    # e se ele é de fato do tipo diretório (flag -d).
    if [ ! -d "$PASTA_ORIGEM" ]; then
        echo " [ERRO] Pasta não encontrada."
        return
    fi

    # [CONCEITO DE SO: CONTROLE DE INTERFACE TTY]
    # 'read -s' (silent) envia uma instrução de controle para o driver do terminal (TTY).
    # Ele desativa o "echo" local, impedindo que os caracteres digitados no Standard Input (teclado)
    # sejam renderizados no Standard Output (tela), protegendo a senha contra leitura de terceiros.
    read -s -p " Crie uma senha para proteger este backup: " SENHA_BKP
    echo "" 
    
    # [CONCEITO DE SO: FORK/EXEC E COMUNICAÇÃO INTERPROCESSOS]
    # A sintaxe $(comando) cria um processo filho (subshell) via chamada 'fork()' para rodar o 'date'.
    # O processo pai (nosso script) aguarda, e o filho injeta seu Standard Output diretamente na variável.
    NOME_BASE="backup_ccs_$(date +%d%m%Y_%H%M)"
    ARQ_TAR="$HOME/${NOME_BASE}.tar.gz"
    ARQ_GPG="$HOME/${NOME_BASE}.gpg"
    
    echo " 📦 1/2 Compactando a pasta..."
    # [CONCEITO DE SO: SOBRECARGA DE I/O E CONSUMO DE CPU]
    # 'tar' arquiva e comprime (a flag -z invoca o gzip). Isso gera operações pesadas de Entrada e Saída (I/O).
    # O processo lê múltiplos arquivos no disco, carrega os blocos para a memória RAM, onde a CPU 
    # executa os algoritmos de compressão, e então executa chamadas 'write()' para gerar o arquivo final.
    tar -czf "$ARQ_TAR" "$PASTA_ORIGEM" 2>/dev/null
    
    echo " 🔒 2/2 Criptografando com AES-256..."
    # [CONCEITO DE SO: PROCESSAMENTO EM ESPAÇO DE USUÁRIO]
    # 'gpg' roda cálculos matemáticos complexos para aplicar a criptografia simétrica.
    # Usamos argumentos de linha de comando (--batch --passphrase) para injetar a variável da senha
    # de forma automatizada, sem exigir um novo prompt interativo bloqueante.
    gpg --symmetric --cipher-algo AES256 --batch --passphrase "$SENHA_BKP" --output "$ARQ_GPG" "$ARQ_TAR" 2>/dev/null
    
    # Validação pós-processamento: checa se o arquivo criptografado foi alocado fisicamente.
    if [ -f "$ARQ_GPG" ]; then
        echo " [OK] Sucesso! Arquivo salvo em: $ARQ_GPG"
        # [CONCEITO DE SO: DESVINCULAÇÃO DE INODES (UNLINK)]
        # Apaga a versão desprotegida para segurança. O comando 'rm' não zera o disco fisicamente; 
        # ele aciona a syscall 'unlink()', que destrói a referência (link) entre o nome do arquivo
        # e o seu Inode. O Kernel então marca aqueles blocos de dados como "livres" para regravação.
        rm -f "$ARQ_TAR" 
    else
        echo " [ERRO] Falha ao gerar o arquivo."
    fi
}
menu_disco() {
    echo "[+] ESPAÇO E HARDWARE DE DISCO (HD/SSD):"
    echo " ----------------------------------------------------------------"
    
    # [CONCEITO DE SO: GERENCIAMENTO DE E/S E DISPOSITIVOS DE BLOCO]
    # 'lsblk' (List Block Devices) consulta a interface do Kernel (arquivos em /sys/dev/block)
    # para abstrair a topologia física de armazenamento. 
    # O '-I 8,259' é um detalhe de nível de Kernel: ele filtra pelos "Major Numbers".
    # O Kernel identifica discos SATA/SCSI pelo Major Number 8, e discos NVMe ultrarrápidos pelo 259.
    # O pipe '|' canaliza esses dados brutos do hardware para o nosso laço de repetição.
    lsblk -d -I 8,259 -n -o ROTA,SIZE,MODEL | while read -r ROTA TAMANHO MODELO; do
        
        # [CONCEITO DE SO: ABSTRAÇÃO DE HARDWARE]
        # 'ROTA' (Rotation) verifica uma flag binária exportada pelo driver do disco no Kernel (0 ou 1).
        # Usamos operadores de curto-circuito (&& para AND lógico, || para OR lógico)
        # para traduzir o status do hardware (Solid State vs. Mecânico) para uma linguagem amigável.
        [ "$ROTA" == "0" ] && TIPO="SSD (Sólido/Rápido)" || TIPO="HD (Disco Mecânico)"
        
        echo "  $TIPO | Capacidade: $TAMANHO | Modelo: $MODELO"
    done
    
    echo " ----------------------------------------------------------------"
    
    # [CONCEITO DE SO: SISTEMA DE ARQUIVOS (VFS) VS. DISCO FÍSICO]
    # Diferente do 'lsblk' que lê o hardware, o 'df' (Disk Free) consulta o espaço lógico.
    # Ele executa uma chamada de sistema (syscall statfs()) para ler o "Superbloco" do 
    # Virtual File System (VFS) montado na raiz (/). O 'awk' no final atua como um 
    # processador de texto, formatando as colunas retornadas pelo comando.
    df -h --output=size,used,avail,pcent / | tail -n 1 | awk '{print " Tamanho Total: "$1" | Espaço Usado: "$2" | Livre: "$3" ("$4")"}'
}

menu_permissoes() {
    echo "[+] GERENCIADOR DE PERMISSÕES:"
    read -p " Caminho do arquivo ou pasta (Ex: ~/arquivo.txt): " ARQ_PERM
    
    # [CONCEITO DE SO: VARIÁVEIS DE AMBIENTE E CAMINHO ABSOLUTO]
    # O Sistema de Arquivos Virtual (VFS) resolve rotas mais rápido com caminhos absolutos.
    # Esta linha faz uma expansão de string para traduzir o caractere '~' (Home)
    # lendo a variável de ambiente de sessão do usuário ($HOME) alocada na RAM.
    ARQ_PERM="${ARQ_PERM/#\~/$HOME}" 
    
    # [CONCEITO DE SO: VALIDAÇÃO DE INODES VIA SYSCALL]
    # O teste '-e' (exists) faz com que o interpretador dispare uma chamada de sistema (syscall stat()).
    # O Kernel vai até o diretório informado e verifica se existe uma entrada válida 
    # apontando para um Inode real no disco antes de prosseguirmos.
    if [ ! -e "$ARQ_PERM" ]; then
        echo " [ERRO] Não encontrado!"
        return 
    fi

    # [CONCEITO DE SO: MATRIZ DE ACESSO POSIX - SUJEITOS]
    # No modelo de segurança do Unix/Linux, o controle de acesso discricionário (DAC) 
    # divide os usuários do sistema em 3 blocos de sujeitos (User, Group, Others), além da opção 'All'.
    echo " PARA QUEM? [1] Dono(u) [2] Grupo(g) [3] Outros(o) [4] Todos(a)"
    read -p " Escolha (1 a 4): " OP_QUEM
    [ "$OP_QUEM" == "1" ] && QUEM="u"
    [ "$OP_QUEM" == "2" ] && QUEM="g"
    [ "$OP_QUEM" == "3" ] && QUEM="o"
    [ "$OP_QUEM" == "4" ] && QUEM="a"

    # [CONCEITO DE SO: LÓGICA DE MANIPULAÇÃO DE BITS]
    # Define se vamos ligar (1) ou desligar (0) o bit de permissão no Inode.
    echo " O QUE FAZER? [1] Adicionar(+) [2] Remover(-)"
    read -p " Escolha (1 ou 2): " OP_ACAO
    [ "$OP_ACAO" == "1" ] && SINAL="+"
    [ "$OP_ACAO" == "2" ] && SINAL="-"

    # [CONCEITO DE SO: MATRIZ DE ACESSO POSIX - DIREITOS]
    # Mapeia os 3 direitos fundamentais de um arquivo no SO: 
    # Ler o conteúdo (r), Modificar os blocos de dados (w) e Solicitar execução à CPU (x).
    echo " QUAL PERMISSÃO? [1] Leitura(r) [2] Escrita(w) [3] Execução(x)"
    read -p " Escolha (1 a 3): " OP_TIPO
    [ "$OP_TIPO" == "1" ] && LETRA="r"
    [ "$OP_TIPO" == "2" ] && LETRA="w"
    [ "$OP_TIPO" == "3" ] && LETRA="x"

    # [CONCEITO DE SO: SYSCALL DE MUDANÇA DE ESTADO (CHMOD)]
    # A flag '-n' testa se as strings não estão vazias (Non-zero length).
    # O script concatena as escolhas (Ex: 'u+x') e invoca o utilitário binário 'chmod'.
    # O 'chmod' atua como um tradutor, acionando o Kernel via chamada de sistema (ex: fchmodat)
    # para reescrever os bits de permissão diretamente no Inode do arquivo, e não nos seus dados.
    if [ -n "$QUEM" ] && [ -n "$SINAL" ] && [ -n "$LETRA" ]; then
        chmod "${QUEM}${SINAL}${LETRA}" "$ARQ_PERM" && echo " [OK] Permissões atualizadas." || echo " [ERRO] Falha."
    else
        echo " [ERRO] Opções inválidas fornecidas."
    fi
}

menu_logs() {
    echo "[+] HISTÓRICO DO SISTEMA (LOGS):"
    read -p " Buscar por alguma palavra? (Ex: erro, usb | ENTER p/ tudo): " FILTRO
    read -p " Quantos resultados quer ver? (ENTER para 10): " QTD_LOGS
    [ -z "$QTD_LOGS" ] && QTD_LOGS=10
    
    echo " ----------------------------------------------------------------"
    
    # [CONCEITO DE SO: DAEMONS E INTER-PROCESS COMMUNICATION (IPC)]
    # 'journalctl' é o cliente que se comunica com o 'systemd-journald', um daemon (processo em background)
    # que coleta logs do Kernel e do Espaço de Usuário. Ao contrário do syslog antigo (que era texto puro),
    # o journald guarda dados em formato binário estruturado. O journalctl faz a leitura e conversão.
    # O pipeline (|) cria canais de memória onde a saída do journalctl alimenta o grep, que alimenta o tail, 
    # que alimenta o awk, formando uma cadeia de processamento multitarefa cooperativa.
    RESULTADO=$(journalctl -b --no-pager -o short 2>/dev/null | grep -i "$FILTRO" | tail -n "$QTD_LOGS" | awk '{
        tempo = $1 " " $2 " " $3; $1=$2=$3=""; print "  [" tempo "] " $0
    }')
    
    [ -z "$RESULTADO" ] && echo " (Nenhuma atividade encontrada com '$FILTRO')" || echo "$RESULTADO"
    echo " ----------------------------------------------------------------"
    
    if [ -n "$RESULTADO" ]; then
        echo " Ações: [1] Salvar .txt | [2] Enviar E-mail | [3] Analisar com IA | [4] Voltar"
        read -p " Escolha: " OP_LOG
        
        if [ "$OP_LOG" == "1" ]; then
            PASTA_LOGS="$HOME/Logs_Sistema"
            [ ! -d "$PASTA_LOGS" ] && mkdir "$PASTA_LOGS"
            
            # [CONCEITO DE SO: REDIRECIONAMENTO DE DESCRITORES (I/O)]
            # O operador '>' aciona a syscall 'open()' com as flags O_WRONLY e O_CREAT. 
            # Ele redireciona o Standard Output (stdout) para um arquivo físico no disco.
            echo "$RESULTADO" > "$PASTA_LOGS/logs_suporte.txt"
            echo " [OK] Salvo em: $PASTA_LOGS/logs_suporte.txt"
            
        elif [ "$OP_LOG" == "2" ]; then
           read -p " Qual o e-mail de destino? (Ex: professor@ifba.edu.br): " EMAIL_DESTINO
                    
                    # [CONCEITO DE SO: SISTEMAS DE ARQUIVOS TEMPORÁRIOS (TMPFS)]
                    # O diretório /tmp geralmente é montado como um 'tmpfs' (armazenado na RAM, não no HD).
                    # Usar o /tmp para arquivos efêmeros economiza ciclos de I/O no disco físico e acelera a execução.
                    ARQ_EMAIL="/tmp/email_logs.txt"
                    IP_ATUAL=$(hostname -I | awk '{print $1}')
                    DATA_HOJE=$(date '+%d%m%Y_%H%M')
                    
                    # [CONCEITO DE SO: IDENTIFICADOR DE PROCESSO (PID)]
                    # A variável especial '$$' retorna o PID (Process ID) do script atual.
                    # O Kernel garante que não existam dois PIDs iguais rodando ao mesmo tempo.
                    # Usar o PID como sufixo garante exclusão mútua e evita colisões se o script rodar duplicado.
                    BOUNDARY="CCS-Boundary-$$"
                    
                    echo " Empacotando os dados, gerando o arquivo .txt e conectando ao Google SMTP..."
                    
                    # 1. CABEÇALHO DO E-MAIL (Injeta dados num arquivo em disco por meio de redirecionamento >>)
                    # O operador '>>' abre o arquivo em modo APPEND (adicionando ao final sem apagar o que já existe).
                    echo "To: $EMAIL_DESTINO" > "$ARQ_EMAIL"
                    echo "From: $MEU_GMAIL" >> "$ARQ_EMAIL"
                    echo "Subject: [CCS] Relatório de Logs do Sistema (Com Anexo)" >> "$ARQ_EMAIL"
                    echo "MIME-Version: 1.0" >> "$ARQ_EMAIL"
                    echo "Content-Type: multipart/mixed; boundary=\"$BOUNDARY\"" >> "$ARQ_EMAIL"
                    echo "" >> "$ARQ_EMAIL" 
                    
                    # 2. CORPO DO E-MAIL (Aviso de anexo em texto puro UTF-8)
                    echo "--$BOUNDARY" >> "$ARQ_EMAIL"
                    echo "Content-Type: text/plain; charset=\"utf-8\"" >> "$ARQ_EMAIL"
                    echo "" >> "$ARQ_EMAIL"
                    echo "Olá," >> "$ARQ_EMAIL"
                    echo "Segue em anexo o arquivo .txt contendo os logs do sistema solicitados via painel CCS." >> "$ARQ_EMAIL"
                    echo "" >> "$ARQ_EMAIL"
                    echo "💻 Máquina: $USER | 🌐 IP: ${IP_ATUAL:-Desconectado}" >> "$ARQ_EMAIL"
                    echo "🔎 Filtro utilizado: ${FILTRO:-Nenhum filtro}" >> "$ARQ_EMAIL"
                    echo "Data de extração: $(date '+%d/%m/%Y às %H:%M:%S')" >> "$ARQ_EMAIL"
                    echo "" >> "$ARQ_EMAIL"
                    
                    # 3. O ANEXO
                    echo "--$BOUNDARY" >> "$ARQ_EMAIL"
                    echo "Content-Type: text/plain; charset=\"utf-8\"" >> "$ARQ_EMAIL"
                    # O 'Content-Disposition' informa ao cliente de email que o trecho a seguir é um arquivo de download.
                    echo "Content-Disposition: attachment; filename=\"logs_suporte_${DATA_HOJE}.txt\"" >> "$ARQ_EMAIL"
                    echo "" >> "$ARQ_EMAIL"
                    echo "$RESULTADO" >> "$ARQ_EMAIL"
                    echo "" >> "$ARQ_EMAIL"
                    
                    # 4. FECHAMENTO DA FRONTEIRA DO PACOTE
                    echo "--$BOUNDARY--" >> "$ARQ_EMAIL"
                    
                    # [CONCEITO DE SO: PILHA TCP/IP E SOCKETS]
                    # O 'curl' solicita ao Kernel a abertura de um Socket de rede. 
                    # Ele delega a comunicação para as camadas inferiores da pilha de rede (TCP porta 465),
                    # estabelecendo o handshake SSL (criptografia) antes de enviar o payload de texto.
                    curl --url 'smtps://smtp.gmail.com:465' \
                         --ssl-reqd \
                         --mail-from "$MEU_GMAIL" \
                         --mail-rcpt "$EMAIL_DESTINO" \
                         --user "$MEU_GMAIL:$SENHA_APP" \
                         -T "$ARQ_EMAIL" 2>/dev/null
                         
                    # [CONCEITO DE SO: CÓDIGOS DE SAÍDA (EXIT STATUS)]
                    # Quando um processo filho (curl) termina, o Kernel envia um sinal (SIGCHLD) ao processo pai (o script)
                    # contendo o código de retorno. '0' é a convenção universal POSIX para sucesso. 
                    # A variável especial '$?' captura esse valor para tomada de decisão.
                    if [ $? -eq 0 ]; then
                         echo " [OK] Relatório enviado com sucesso para $EMAIL_DESTINO! (Verifique o Spam. Anexo .txt gerado)"
                    else
                         echo " [ERRO] Falha ao enviar. Verifique sua conexão ou a Senha de Aplicativo."
                    fi
                    
                    # [CONCEITO DE SO: DESALOCAÇÃO DE RECURSOS]
                    # Limpeza de rastro no disco. A syscall 'unlink()' é chamada para remover o Inode
                    # do arquivo temporário gerado no /tmp, liberando a memória alocada.
                    rm -f "$ARQ_EMAIL"
                    
        elif [ "$OP_LOG" == "3" ]; then
            PROMPT="Você é um especialista em suporte Linux. O usuário extraiu o seguinte log do systemd: \n ${RESULTADO}. \n Explique o que esses logs significam em linguagem simples. Caso haja um erro grave, indique as possíveis causas. NUNCA sugira comandos arbitrários."
            # Submete o contexto montado a API remota 
            consultar_ia "$PROMPT"
        fi
    fi
}

# ================================================================
# VERIFICAÇÃO DOS ARGUMENTOS DA LINHA DE COMANDO
# ================================================================
# A variável especial $1 armazena o primeiro argumento passado após o nome do script (Ex: ./projeto.sh -h)
case "$1" in
    -h|--help|-help) mostrar_help; exit 0 ;;
    "") ;; # Executa normalmente
    *) echo " [ERRO] Argumento desconhecido: $1"; exit 1 ;;
esac

# ================================================================
# LOOP PRINCIPAL (ROTEADOR DE OPÇÕES)
# ================================================================
# Loop infinito que renderiza as opções gráficas do painel para o usuário e coordena a orquestração do programa
while true; do
    clear
    echo "================================================================"
    echo "                  ____  ____  ____                                   "
    echo "                 / ___|/ ___|/ ___|                                  "
    echo "                | |   | |    \___ \                                  "
    echo "                | |___| |___  ___) |                                 "
    echo "                 \____|\____||____/                                  "
    echo "----------------------------------------------------------------"
    echo "               CENTRO DE CONTROLE DE SISTEMAS                   "
    echo "================================================================"
    echo " 1 - Informações do sistema      | 5 - Espaço em disco"
    echo " 2 - Monitor de processos        | 6 - Permissões"
    echo " 3 - Encontrar um arquivo        | 7 - Logs do sistema"
    echo " 4 - Backup Local Criptografado  | 8 - Sair do Painel"
    echo "----------------------------------------------------------------"
    echo " Dica: Digite -h a qualquer momento para abrir a Ajuda"
    echo "================================================================"
    read -p " Digite o número da opção desejada: " OPCAO
    echo "----------------------------------------------------------------"

    # Roteador (Switch): executa o sub-módulo (função) com base na escolha numérica.
    case "$OPCAO" in
        -h|--help|-help) mostrar_help ;;
        1) menu_informacoes ;;
        2) menu_processos ;;
        3) menu_arquivos ;;
        4) menu_backup ;;
        5) menu_disco ;;
        6) menu_permissoes ;;
        7) menu_logs ;;
        8) exit 0 ;; # Desliga a thread principal do programa emitindo status 0 (sucesso)
        *) echo " [ERRO] Opção inválida! Digite de 1 a 8." ;;
    esac
    
    echo "----------------------------------------------------------------"
    read -p " Pressione [ENTER] para voltar ao menu principal..."
done
