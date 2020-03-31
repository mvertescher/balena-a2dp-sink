#!/usr/bin/env bash

BLUETOOTH_DEVICE_NAME=$(printf "a2dp-sink-%s" $(hostname | cut -c -4))

# Set the system volume here
SYSTEM_OUTPUT_VOLUME="${SYSTEM_OUTPUT_VOLUME:-75}"
echo $SYSTEM_OUTPUT_VOLUME > /usr/src/system_output_volume
printf "Setting output volume to %s%%\n" "$SYSTEM_OUTPUT_VOLUME"
amixer sset PCM,0 $SYSTEM_OUTPUT_VOLUME% > /dev/null &
amixer sset Digital,0 $SYSTEM_OUTPUT_VOLUME% > /dev/null &

# Set the discoverable timeout here
dbus-send --system --dest=org.bluez --print-reply /org/bluez/hci0 \
  org.freedesktop.DBus.Properties.Set string:'org.bluez.Adapter1' \
  string:'DiscoverableTimeout' variant:uint32:0 > /dev/null

printf "Restarting bluetooth service\n"
service bluetooth restart > /dev/null
sleep 2

# Redirect stdout to null, because it prints the old BT device name, which
# can be confusing and it also hides those commands from the logs as well.
printf "discoverable on\npairable on\nexit\n" | bluetoothctl > /dev/null

sleep 2
rm -rf /var/run/bluealsa/
/usr/bin/bluealsa -i hci0 -p a2dp-sink &

# Disable onboard bluetooth if using a bluetooth dongle
# (onboard interface gets remapped to hci1)
hciconfig hci1 down > /dev/null 2>&1

hciconfig hci0 up
hciconfig hci0 name "$BLUETOOTH_DEVICE_NAME"

# Use Secure Simple Pairing
hciconfig hci0 sspmode 1
printf "Starting bluetooth agent in Secure Simple Pairing Mode (SSPM) - No PIN code provided or invalid\n"

sleep 2
printf "Device is discoverable as \"%s\"\n" "$BLUETOOTH_DEVICE_NAME"
exec /usr/bin/bluealsa-aplay --pcm-buffer-time=1000000 00:00:00:00:00:00
