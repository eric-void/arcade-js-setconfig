# arcade-js-setconfig
Shell script to set emulationstation/batocera controller order at boot.

Use it when your arcade joysticks / joypads sometimes change order at boot.

This script detect devices by their "Phys" address on /proc/bus/input/devices (a unique property that don't change between boots), then save them (in correct order) in _es_settings.cfg_ file.

20250108 UPDATE: after a month without any problems, one night unexpectedly the PHYS addresses of my joysticks changed :(
I updated the script to let you specify a list of Phys addresses for each player.

## Usage

To use it you must first detect your controllers PHYS addresses, and place them in _arcade-js-setconfig.settings_ file.

Use "**arcade-js-setconfig.sh list**" to show current detected devices, and copy the PHYS address, then put them, in correct order in PHYS["P#"] setting (P# = P1, P2 ...).

After that you can use the command below:

**arcade-js-setconfig.sh test**: test the controller detection and see how the emulationstation config file will be changed.

**arcade-js-setconfig.sh save**: change the emulationstation config file.

## Installation on batocera

Copy the script on a /userdata/ path (for my scripts i use "_/userdata/bin_") and "_chmod +x_" it to set executable flag.

Edit _arcade-js-setconfig.settings_ to set PHYS addresses of your devices (use _arcade-js-setconfig.sh list_ to detect them).

To run the script at boot, put it in your _/boot/postshare.sh_ file on "start" section.
For example, if you don't have a previous postshare.sh, you can simply put this:

```
#!/bin/bash
if [ "$1" == "start" ] then /userdata/bin/arcade-js-setconfig.sh save; fi
```

(Remember, to edit /boot partition you should remount it in read-write mode, with this command: _mount -o remount,rw /boot_)

## Configuration

You can use settings below to change configuration

```
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
```
