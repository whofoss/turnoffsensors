
#!/system/bin/sh

# Aguarda o serviço sensor_privacy estar disponível
MAX_ATTEMPTS=100
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if service list | grep -q "sensor_privacy"; then
        break
    fi
    sleep 0.1
    ATTEMPT=$((ATTEMPT + 1))
done

# Verifica se o serviço foi encontrado
if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo "Erro: sensor_privacy não disponível"
    exit 1
fi

# Obtém versão do Android
ANDROID_VERSION=$(getprop ro.build.version.release)

# Determina o código de chamada do serviço baseado na versão
case "$ANDROID_VERSION" in
    13|14|15|16)
        SERVICE_CODE=9
        ;;
    12)
        SERVICE_CODE=8
        ;;
    10|11)
        SERVICE_CODE=4
        ;;
    *)
        echo "Erro: Versão do Android não reconhecida: $ANDROID_VERSION"
        exit 1
        ;;
esac

# Define arquivo de estado (em /data/local/tmp que sempre existe)
STATE_FILE="/data/local/tmp/sensor_privacy_state"

# Verifica estado atual e alterna
if [ -f "$STATE_FILE" ]; then
    # Desativar
    service call sensor_privacy $SERVICE_CODE i32 0
    rm -f "$STATE_FILE"
    echo "sensor_privacy DESATIVADO"
else
    # Ativar
    service call sensor_privacy $SERVICE_CODE i32 1
    echo "1" > "$STATE_FILE"
    echo "sensor_privacy ATIVADO"
fi

sleep 1