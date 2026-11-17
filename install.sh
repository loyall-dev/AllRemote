#!/data/data/com.termux/files/usr/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
PURPLE='\033[0;35m'
NC='\033[0m'

clear

echo -e "${GREEN}"
cat << "EOF"
  ██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗
 ██╔════╝ ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝
 ██║  ███╗███████║██║   ██║███████╗   ██║   
 ██║   ██║██╔══██║██║   ██║╚════██║   ██║   
 ╚██████╔╝██║  ██║╚██████╔╝███████║   ██║   
  ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝   
EOF
echo -e "${WHITE}          R E M O T E   S Y S T E M${NC}"
echo -e "${PURPLE}==========================================${NC}"
sleep 2

echo -e "\n${YELLOW}[*] Verificando dependências do sistema...${NC}"

if ! command -v adb &> /dev/null || ! command -v curl &> /dev/null; then
    echo -e "${YELLOW}[*] Instalando pacotes necessários (android-tools, curl)...${NC}"
    pkg update -y &> /dev/null
    pkg install android-tools curl -y &> /dev/null
    echo -e "${GREEN}[+] Dependências instaladas com sucesso.${NC}"
else
    echo -e "${GREEN}[+] Dependências OK (adb e curl encontrados).${NC}"
fi

echo -e "\n${YELLOW}[*] Instalando interface de controle...${NC}"

cat > /data/data/com.termux/files/usr/bin/ghost << 'GHOST_EOF'
#!/data/data/com.termux/files/usr/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
PURPLE='\033[0;35m'
NC='\033[0m'

declare -A ESTADO
for i in {1..20}; do ESTADO[$i]=0; done

clear
echo -e "${PURPLE}==========================================${NC}"
echo -e "${WHITE}            AUTENTICAÇÃO WALI BYPASS            ${NC}"
echo -e "${PURPLE}==========================================${NC}\n"

ADB_STATE=$(adb get-state 2>/dev/null | tr -d '\r\n')

if [ "$ADB_STATE" == "device" ]; then
    echo -e "${GREEN}[+] Sistema ADB já conectado.${NC}"
    TARGET_IP=$(adb devices | grep -v "List" | grep "device" | head -n1 | awk '{print $1}' | cut -d':' -f1)
    sleep 1
else
    echo -e "${WHITE}Etapa 1: Conexão com o Dispositivo${NC}"
    echo -e "${YELLOW}O ADB não está conectado. Vamos configurar agora.${NC}\n"
    
    echo -n "IP:PORTA de PAREAMENTO: "
    read -r PAIR_ADDR < /dev/tty
    
    echo -n "Código de 6 dígitos: "
    read -r PAIR_CODE < /dev/tty
    
    echo -e "\n${YELLOW}[*] Pareando dispositivos...${NC}"
    adb pair $PAIR_ADDR $PAIR_CODE
    
    echo -n "IP:PORTA de CONEXÃO: "
    read -r CONN_ADDR < /dev/tty
    
    echo -e "${YELLOW}[*] Estabelecendo conexão segura...${NC}"
    adb connect $CONN_ADDR
    sleep 1
    
    if [ "$(adb get-state 2>/dev/null | tr -d '\r\n')" != "device" ]; then
        echo -e "${RED}[!] Falha na conexão. Verifique os dados e tente novamente.${NC}"
        exit 1
    fi
    # Pega o IP que o usuário digitou (remove a porta)
    TARGET_IP=$(echo $CONN_ADDR | cut -d':' -f1)
fi

# Cria o Túnel Reverso (Manda o ADB escutar no celular de controle e redirecionar pro alvo)
echo -e "${YELLOW}[*] Criando túnel ADB (isso pode levar 1 seg)...${NC}"
adb forward tcp:7755 tcp:7755

HWID=$(adb shell settings get secure android_id 2>/dev/null | tr -d '\r\n')
if [ -z "$HWID" ] || [ "$HWID" == "null" ]; then
    echo -e "${RED}[!] Falha ao obter o Hardware ID. Verifique o ADB.${NC}"
    exit 1
fi

clear
echo -e "${PURPLE}==========================================${NC}"
echo -e "${WHITE}             VALIDAÇÃO DE LICENÇA         ${NC}"
echo -e "${PURPLE}==========================================${NC}\n"

echo -n "Insira sua Key de Acesso: "
read -r USER_KEY < /dev/tty

echo -e "\n${YELLOW}[*] Comunicando com o servidor...${NC}"

K_API=$(echo "aHR0cHM6Ly90ZWFtcmVzZWxsLXBqazM2bG5iLm1hbnVzLnNwYWNlL2FwaS9QUk9YWU1FTlVMb2dpbi5waHA=" | base64 -d)

# A API PROXYMENU usa GET com os parâmetros obrigatórios key e hwid.
# --data-urlencode evita quebrar a URL caso a key contenha caracteres especiais.
USER_KEY=$(printf '%s' "$USER_KEY" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
HWID=$(printf '%s' "$HWID" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

RESPONSE=$(curl -sS --get --max-time 10 \
  --data-urlencode "key=$USER_KEY" \
  --data-urlencode "hwid=$HWID" \
  "$K_API")

SUCCESS=$(printf '%s' "$RESPONSE" | sed -n 's/.*"success"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p' | head -n1)
STATUS=$(printf '%s' "$RESPONSE" | sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
DAYS_LEFT=$(printf '%s' "$RESPONSE" | sed -n 's/.*"days_left"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -n1)
MESSAGE=$(printf '%s' "$RESPONSE" | sed -n 's/.*"message"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)

if [ "$SUCCESS" != "true" ] || [ "$STATUS" != "active" ]; then
    if [ -n "$MESSAGE" ]; then
        echo -e "${RED}[!] Acesso Negado: $MESSAGE${NC}"
    else
        echo -e "${RED}[!] Acesso Negado. Key inválida ou expirada.${NC}"
    fi
    sleep 3
    exit 1
fi

echo -e "${GREEN}[+] Acesso Autorizado!${NC}"
if [ -n "$DAYS_LEFT" ]; then
    echo -e "${GREEN}[+] Expira em aproximadamente ${DAYS_LEFT} dias.${NC}"
fi
sleep 2

clear
echo -e "${PURPLE}==========================================${NC}"
echo -e "${WHITE}             INJEÇÃO DO MÓDULO            ${NC}"
echo -e "${PURPLE}==========================================${NC}\n"
echo -e "${WHITE}Abra o Amazon no celular alvo, clique em INJETAR e feche o app."
echo -e "Após abrir o Free Fire, retorne a esta tela.${NC}\n"
echo -n "Módulo injetado e FF aberto? (s/n): "
read -r INJETADO < /dev/tty

if [ "$INJETADO" != "s" ]; then
    echo -e "${RED}[!] Operação cancelada.${NC}"
    exit 1
fi

while true; do
    clear
    echo -e "${PURPLE}==========================================${NC}"
    echo -e "${WHITE}              WALI BYPASS - REMOTE                ${NC}"
    echo -e "${PURPLE}==========================================${NC}\n"
    
    status() {
        if [ "${ESTADO[$1]}" -eq 1 ]; then echo -e "${GREEN}[ON]${NC}"; fi
    }

    echo -e "${CYAN}┌── AIMBOTS ─────────────────────────────┐${NC}"
    echo -e "  [1] Aim Memory  $(status 1)"
    echo -e "  [2] Aim Legit (Pescoço)        $(status 2)"
    
    echo -e "\n${CYAN}┌── ESP (VISÃO) ─────────────────────────┐${NC}"
    echo -e "  [3] ESP Box (Caixa)            $(status 3)"
    echo -e "  [4] ESP Linha (Topo)           $(status 4)"
    echo -e "  [5] ESP Nickname               $(status 5)"
    echo -e "  [6] ESP Vida (Health)          $(status 6)"
    echo -e "  [7] Esqueleto Branco           $(status 7)"
    echo -e "  [8] Distância em Metros        $(status 8)"

    echo -e "\n${CYAN}┌── OUTRAS FUNÇÕES ──────────────────────┐${NC}"
    echo -e "  [9] Aim FOV               $(status 9)"
    echo -e "  [10] Fast Switch               $(status 10)"
    echo -e "  [11] No Recoil          $(status 11)"
    echo -e "${CYAN}└────────────────────────────────────────┘${NC}"
    
    echo -e "\n${RED}┌── DESCONECTAR / LIMPAR (BYPASS) ───────┐${NC}"
    echo -e "  [99] Limpar arquivos e desinstalar Amazon"
    echo -e "${RED}└────────────────────────────────────────┘${NC}"

    echo -e "\n  [0] Encerrar Sessão"
    echo -e ""
    echo -n "  » Selecione: "
    read -r FUNC_OPT < /dev/tty

    if [ "$FUNC_OPT" == "99" ]; then
        echo -e "\n${RED}[!] AVISO: Isso vai desligar tudo e desinstalar o app Amazon.${NC}"
        echo -n "Tem certeza? (s/n): "
        read -r CONFIRMA < /dev/tty
        
        if [ "$CONFIRMA" == "s" ]; then
            echo -e "\n${YELLOW}[*] Desativando todas as funções...${NC}"
            for i in 1 2 3 5 6 7 9 10 11 14 15; do
                curl -s -H "Connection: close" --max-time 1 "http://127.0.0.1:7755/item$i/desativar" > /dev/null
            done

            echo -e "${YELLOW}[*] Fechando o Free Fire...${NC}"
            adb shell am force-stop com.dts.freefireth
            
            echo -e "${YELLOW}[*] Apagando os arquivos do cheat...${NC}"
            adb shell "rm -f /sdcard/Android/data/com.dts.freefireth/files/Assembly-CSharp-patch.bytes /sdcard/Android/data/com.dts.freefireth/files/xyz.guard /sdcard/Android/data/com.dts.freefireth/files/localConfig.json /sdcard/Android/data/com.dts.freefireth/files/auth.txt /sdcard/Android/data/com.dts.freefireth/files/ffrtc_log.txt /sdcard/Android/data/com.dts.freefireth/files/ShaderStripSettings /sdcard/Android/data/com.dts.freefireth/files/reportnew.db"
            
            echo -e "${YELLOW}[*] Desinstalando o app Amazon...${NC}"
            adb shell am force-stop com.zyron
            adb shell pm uninstall com.zyron
            
            echo -e "\n${GREEN}[+] Bypass concluído!${NC}"
            sleep 3
            exit 0
        fi
    fi

    case $FUNC_OPT in
        1) ENDPOINT="item1"; NAME="HS Cabeça" ;;
        2) ENDPOINT="item5"; NAME="Drag Neck" ;;
        3) ENDPOINT="item3"; NAME="ESP Box" ;;
        4) ENDPOINT="item2"; NAME="ESP Linha" ;;
        5) ENDPOINT="item6"; NAME="ESP Nickname" ;;
        6) ENDPOINT="item7"; NAME="ESP Vida" ;;
        7) ENDPOINT="item9"; NAME="Esqueleto Branco" ;;
        8) ENDPOINT="item10"; NAME="Distância" ;;
        9) ENDPOINT="item11"; NAME="FOV Perfeito" ;;
        10) ENDPOINT="item14"; NAME="Fast Switch" ;;
        11) ENDPOINT="item15"; NAME="No Recoil" ;;
        0) clear; exit 0 ;;
        *) continue ;;
    esac

    echo -e "\n${YELLOW}[*] Sincronizando...${NC}"
    
    if [ "${ESTADO[$FUNC_OPT]}" -eq 0 ]; then
        curl -s -H "Connection: close" --max-time 2 "http://127.0.0.1:7755/$ENDPOINT" > /dev/null
        ESTADO[$FUNC_OPT]=1
        echo -e "${GREEN}[+] $NAME: ATIVADO${NC}"
    else
        curl -s -H "Connection: close" --max-time 2 "http://127.0.0.1:7755/$ENDPOINT/desativar" > /dev/null
        ESTADO[$FUNC_OPT]=0
        echo -e "${RED}[-] $NAME: DESATIVADO${NC}"
    fi
    sleep 1.5
done
GHOST_EOF

chmod +x /data/data/com.termux/files/usr/bin/ghost
ghost
ENDSCRIPT
chmod +x install.sh
./install.sh
