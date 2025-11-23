#!/system/bin/sh

modules_dir="/data/adb/modules/Surfing"
[ -n "$(magisk -v | grep lite)" ] && MODULE_DIR="/data/adb/lite_modules/Surfing"

SCRIPTS_DIR="/data/adb/box_bll/scripts"

(
until [ "$(getprop sys.boot_completed)" -eq 1 ]; do
  sleep 3
done
${SCRIPTS_DIR}/start.sh
) &

HOSTS_PATH="/data/adb/box_bll/clash/etc/"
HOSTS_FILE="/data/adb/box_bll/clash/etc/hosts"
SYSTEM_HOSTS="/system/etc/hosts"

mkdir -p "$HOSTS_PATH"

inotifyd ${SCRIPTS_DIR}/box.inotify ${modules_dir} > /dev/null 2>&1 &
inotifyd ${SCRIPTS_DIR}/box.inotify "$HOSTS_PATH" >/dev/null 2>&1 &
    
mount -o bind "$HOSTS_FILE" "$SYSTEM_HOSTS"

NET_DIR="/data/misc/net"
while [ ! -f /data/misc/net/rt_tables ]; do
  sleep 3
done

inotifyd ${SCRIPTS_DIR}/net.inotify "$NET_DIR" > /dev/null 2>&1 &
inotifyd ${SCRIPTS_DIR}/ctr.inotify /data/misc/net/rt_tables > /dev/null 2>&1 &

is_oneplus_coloros16() {
    [ "$(getprop ro.product.brand)" != "OnePlus" ] && return 1

    local version
    version=$(getprop ro.build.version.oplusos)

    case "$version" in
        16*|ColorOS16* ) return 0 ;;
        * ) return 1 ;;
    esac
}

delete_op_coloros16_fw_rules() {
    is_oneplus_coloros16 || return 0

    local KEYWORDS="rmnet+ wlan+"
    for chain in fw_INPUT fw_OUTPUT; do
        iptables -t filter -nL "$chain" >/dev/null 2>&1 || continue

        for keyword in $KEYWORDS; do
            local lines
            lines=$(iptables -t filter -nL "$chain" --line-numbers \
                    | grep "$keyword" \
                    | grep "DROP" \
                    | awk '{print $1}' \
                    | sort -rn)

            for line in $lines; do
                iptables -t filter -D "$chain" "$line" 2>/dev/null
            done
        done
    done
}