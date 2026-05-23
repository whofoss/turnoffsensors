# service.sh
MODDIR="${0%/*}"

STATE_FILE="/data/local/tmp/sensor_privacy_state"

notify() {
    _TITLE="$1"
    _MSG="$2"
    su -lp 2000 -c "cmd notification post -S bigtext -t '$_TITLE' 'sensor_privacy' '$_MSG'"
}

get_service_code() {
    case "$(getprop ro.build.version.release)" in
        13|14|15|16) echo 9 ;;
        12)          echo 8 ;;
        10|11)       echo 4 ;;
        *)           echo "" ;;
    esac
}

get_screen_state() {
    _PWR=$(dumpsys power 2>/dev/null)
    if echo "$_PWR" | grep -qE "mWakefulness=Awake|mWakefulnessRaw=Awake"; then
        if dumpsys window 2>/dev/null | grep -qE "mShowingDream=true|mDreamingLockscreen=true"; then
            echo "OFF"
            return
        fi
        echo "ON"
        return
    fi
    for BL in /sys/class/leds/lcd-backlight/brightness /sys/class/backlight/panel0-backlight/brightness; do
        if [ -f "$BL" ]; then
            _BRI=$(cat "$BL" 2>/dev/null)
            [ "${_BRI:-0}" -gt 0 ] && echo "ON" && return
        fi
    done
    echo "OFF"
}

set_battery_saver() {
    # $1: 1 = ativar, 0 = desativar
    settings put global low_power "$1" 2>/dev/null
}

toggle_sensor_privacy() {
    MAX_ATTEMPTS=100
    ATTEMPT=0

    while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
        if service list | grep -q "sensor_privacy"; then
            break
        fi
        sleep 1
        ATTEMPT=$((ATTEMPT + 1))
    done

    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        notify "Sensor Privacy" "Erro: sensor_privacy não disponível"
        return 1
    fi

    SERVICE_CODE=$(get_service_code)
    [ -z "$SERVICE_CODE" ] && notify "Sensor Privacy" "Erro: versão não reconhecida" && return 1

    if [ -f "$STATE_FILE" ]; then
        service call sensor_privacy $SERVICE_CODE i32 0
        rm -f "$STATE_FILE"
        notify "Sensor Privacy" "Microfone e câmera LIBERADOS"
    else
        service call sensor_privacy $SERVICE_CODE i32 1
        echo "1" > "$STATE_FILE"
        notify "Sensor Privacy" "Microfone e câmera BLOQUEADOS"
    fi
}

lock_sensors() {
    SERVICE_CODE=$(get_service_code)
    [ -z "$SERVICE_CODE" ] && return 1

    if [ ! -f "$STATE_FILE" ]; then
        service call sensor_privacy $SERVICE_CODE i32 1
        echo "1" > "$STATE_FILE"
        set_battery_saver 1
        notify "Sensor Privacy" "Tela desligada — microfone e câmera BLOQUEADOS, economia de bateria ATIVADA"
    fi
}

unlock_sensors() {
    SERVICE_CODE=$(get_service_code)
    [ -z "$SERVICE_CODE" ] && return 1

    if [ -f "$STATE_FILE" ]; then
        service call sensor_privacy $SERVICE_CODE i32 0
        rm -f "$STATE_FILE"
        set_battery_saver 0
        notify "Sensor Privacy" "Tela ligada — microfone e câmera LIBERADOS, economia de bateria DESATIVADA"
    fi
}

# Bloqueia no boot se a tela já estiver desligada
if [ "$(get_screen_state)" = "OFF" ]; then
    lock_sensors
fi

PREV_STATE=$(get_screen_state)

while true; do
    CURR_STATE=$(get_screen_state)

    if [ "$CURR_STATE" = "ON" ] && [ "$PREV_STATE" = "OFF" ]; then
        unlock_sensors
        POLL_INTERVAL=2
    elif [ "$CURR_STATE" = "OFF" ] && [ "$PREV_STATE" = "ON" ]; then
        lock_sensors
        POLL_INTERVAL=5
    fi

    PREV_STATE="$CURR_STATE"
    sleep "${POLL_INTERVAL:-2}"
done