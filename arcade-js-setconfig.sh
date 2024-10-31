#!/bin/bash

# Force joystick order in EmulationStation config, detecting devices by their "Phys" address on /proc/bus/input/devices (a unique property that don't change between boots).
# Install on a batocera system by loading it in /boot/postshare.sh (use "mount -o remount,rw /boot" to write the file)
# For example:
# if [ "$1" == "start" ] then /userdata/bin/arcade-js-setconfig.sh save; fi

# Use arcade-js-setconfig.sh for a dry-run execution (test the command without saving the result)

# ----------
# Default options
# Do NOT change these, place your local options in "arcade-js-setconfig.settings" file

# In "PHYS" variable insert, in correct order, "Phys" addresses of devices. You can find them by using the command "arcade-js-setconfig.sh list"
# For full raw data:
# cat /proc/bus/input/devices | grep "\(Joystick\|lightgun\|pad\)" -A 10 -B 1
declare -A PHYS
# Example:
# PHYS["P1"]="usb-0000:00:14.0-9/input0"
# PHYS["P2"]="usb-0000:00:14.0-10/input0"

# Path to EmulationStation config file
CFGFILE=/userdata/system/configs/emulationstation/es_settings.cfg

# Extension used for backup of previous es_settings.cfg file. Leave empty to disable backup
CFGBACKUPEXT=.bak.$(date +%Y%m%d)

# Regular expression to extract from "Sysfs" property the path to the device used by EmulationStation PATH config
# For example: Sysfs=/devices/pci0000:00/0000:00:14.0/usb1/1-10/1-10:1.0/0003:0079:0006.0009/input/input25
# Should extract: /devices/pci0000:00/0000:00:14.0/usb1/1-10/1-10:1.0
SYSFS_REGEX="^(/devices/[^/]+/[^/]+/[^:]+:[0-9]+(\.[0-9]+)?)/.*"

# ----------

if [ -f arcade-js-setconfig.settings ]; then
    . arcade-js-setconfig.settings
else
    DIR=$(dirname $0)
    . $DIR/arcade-js-setconfig.settings
fi

if [ ! "$1" ]; then
    echo "Syntax: $0 [list|test|save]"
    exit 1
fi

if [ ! -f /proc/bus/input/devices ]; then
    echo "ERROR: /proc/bus/input/devices not found"
    exit 1
fi
if [ ! -f $CFGFILE ]; then
    echo "ERROR: $CFGFILE not found"
    exit 1
fi
hash sdl2-jstest 2>/dev/null || { echo >&2 "ERROR: command 'sdl2-jstest' not found"; exit 1; }

if [ "$1" == "list" ]; then
    echo "joystick devices detected on /proc/bus/input/devices:"
    echo "----------"
    cat /proc/bus/input/devices | grep "\(Joystick\|lightgun\|pad\)" -A 10 -B 1 | grep "\(Bus\|Name\|Phys\|Sysfs\|Handlers\)"
    echo -e "\nsdl2-jstest output:"
    echo "----------"
    sdl2-jstest --list | grep Joystick
    echo ""
    exit 0
fi

RESULT=""

for pkey in "${!PHYS[@]}"; do
    phys_address=${PHYS[${pkey}]}
    echo "Detecting device ${pkey} = ${phys_address} ..."
    # Var reset
    Name=""
    SysFs=""
    Handlers=""
    SysPath=""
    JsEvent=""
    GuidRaw=""
    Guid=""

    # Usa awk per estrarre le righe dal file
    while IFS= read -r line; do
        # Filtra solo le righe nel formato "K=VALUE"
        if [[ "$line" =~ ^[[:space:]]*[A-Z]+:[[:space:]]*([^=]+)=(.*) ]]; then
            key="${BASH_REMATCH[1]}"   # Estrarre il nome della variabile (K)
            value="${BASH_REMATCH[2]}" # Estrarre il valore della variabile (VALUE)

            # Rimuove i doppi apici dal valore, se presenti
            value="${value%\"}"  # Rimuove l'ultimo doppio apice
            value="${value#\"}"  # Rimuove il primo doppio apice

            # Esportare la variabile di ambiente
            export "$key"="$value"
            # echo "Impostata la variabile: $key=\"$value\""
        fi
    done < <(awk -v addr="$phys_address" '
        BEGIN {
            output = 0  # Variabile per controllare l output
        }

        # Inizia a salvare le righe in un blocco non appena si incontra una riga vuota o l inizio del file
        /^$/ {
            block = ""
        }

        # Aggiungi la riga corrente al blocco
        {
            block = block $0 "\n"
        }

        # Se la riga contiene "Phys=<indirizzo>", inizia l output
        /Phys=/ && $0 ~ addr {
            output = 1
        }

        # Se l output è attivo, stampa tutte le righe fino alla riga vuota successiva
        output {
            print block
            block = ""  # Resetta il blocco
        }

        # Disabilita l output dopo una riga vuota
        output && /^$/ {
            output = 0
        }
    ' /proc/bus/input/devices)

    if [ "$Name" -a "$Sysfs" -a "$Handlers" ]; then
        echo " ... found on /proc/bus/input/devices with name:$Name, sysfs:$Sysfs, handlers:$Handlers"
        if [[ "$Sysfs" =~ $SYSFS_REGEX ]]; then
            SysPath=/sys${BASH_REMATCH[1]}
        fi
        if [[ "$Handlers" =~ (event[0-9]+) ]]; then
            JsEvent=/dev/input/${BASH_REMATCH[1]}
        fi
        if [ "$SysPath" -a "$JsEvent" ]; then
            echo " ... syspath: $SysPath, jsevent: $JsEvent"
            GuidRaw=`sdl2-jstest --list | grep "$JsEvent" -A 1 | grep "Joystick GUID:"`
            if [[ "$GuidRaw" =~ GUID:[[:space:]]*([a-z0-9]*) ]]; then
                Guid=${BASH_REMATCH[1]}
                echo " ... found on sdl2-jstest with GUID: $Guid"

                RESULT="${RESULT}        <string name=\"INPUT ${pkey}GUID\" value=\"${Guid}\" />\n"
                RESULT="${RESULT}        <string name=\"INPUT ${pkey}NAME\" value=\"${Name}\" />\n"
                RESULT="${RESULT}        <string name=\"INPUT ${pkey}PATH\" value=\"${SysPath}\" />\n"
            else
                echo " ... ERROR: GUID not found with sdl2-jstest"
            fi
        else
            echo " ... ERROR: sysfs or handlers not recognized"
        fi
    else
        echo " ... not found"
    fi
done

if [ ! "$RESULT" ]; then
    echo -e "\nERROR: No address found, nothing to do"
    exit 1
fi

#  | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' used only to remove final empty lines
grep -v "<string name=\"INPUT P" ${CFGFILE} | grep -v "</config>" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > ${CFGFILE}.tmp
echo -e "$RESULT" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' | sort >> ${CFGFILE}.tmp
echo -e "</config>" >> ${CFGFILE}.tmp

if [ "$1" == "test" ]; then
    echo -e "\nResult:"
    cat ${CFGFILE}.tmp
    rm -f ${CFGFILE}.tmp
fi
if [ "$1" == "save" ]; then
    if [ "$CFGBACKUPEXT" != "" ]; then
        mv ${CFGFILE} ${CFGFILE}${CFGBACKUPEXT}
    fi
    mv ${CFGFILE}.tmp ${CFGFILE}
    echo -e "\nSaved to ${CFGFILE}"
fi
