#!/bin/bash
# Part of raspi-config https://github.com/RPi-Distro/raspi-config
#
# See LICENSE file for copyright and license details
# Revised:  8/07/2018

INTERACTIVE=True
ASK_TO_REBOOT=0
BLACKLIST=/etc/modprobe.d/raspi-blacklist.conf
CONFIG=/boot/config.txt

# Execute a command as root (or sudo)
do_with_root() {
    # already root? "Just do it" (tm).
    if [[ `whoami` = 'root' ]]; then
        $*
    elif [[ -x /usr/bin/sudo || -x /bin/sudo ]]; then
        echo "sudo $*"
        sudo $*
    else
        echo "Raspi-Config requires root privileges to install."
        echo "Please run this script as root."
        exit 1
    fi
}

{ # Testing for is_pi
is_pi () {
  ARCH=$(dpkg --print-architecture)
  if [ "$ARCH" = "armhf" ] ; then
    return 0
  else
    return 1
  fi
}

if is_pi ; then
  CMDLINE=/boot/cmdline.txt
else
  CMDLINE=/proc/cmdline
fi
}

is_pione() {
   if grep -q "^Revision\s*:\s*00[0-9a-fA-F][0-9a-fA-F]$" /proc/cpuinfo; then
      return 0
   elif grep -q "^Revision\s*:\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]0[0-36][0-9a-fA-F]$" /proc/cpuinfo ; then
      return 0
   else
      return 1
   fi
}

is_pitwo() {
   grep -q "^Revision\s*:\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]04[0-9a-fA-F]$" /proc/cpuinfo
   return $?
}

is_pizero() {
   grep -q "^Revision\s*:\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]0[9cC][0-9a-fA-F]$" /proc/cpuinfo
   return $?
}

get_pi_type() {
   if is_pione; then
      echo 1
   elif is_pitwo; then
      echo 2
   else
      echo 0
   fi
}

is_live() {
    grep -q "boot=live" $CMDLINE
    return $?
}

is_ssh() {
  if pstree -p | egrep --quiet --extended-regexp ".*sshd.*\($$\)"; then
    return 0
  else
    return 1
  fi
}

calc_wt_size() {
  # NOTE: it's tempting to redirect stderr to /dev/null, so supress error
  # output from tput. However in this case, tput detects neither stdout or
  # stderr is a tty and so only gives default 80, 24 values
  WT_HEIGHT=17
  WT_WIDTH=$(tput cols)

  if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 60 ]; then
    WT_WIDTH=80
  fi
  if [ "$WT_WIDTH" -gt 178 ]; then
    WT_WIDTH=120
  fi
  WT_MENU_HEIGHT=$(($WT_HEIGHT-7))
}

do_about() {
  whiptail --msgbox "\
This tool provides a straight-forward way of doing initial
configuration of the Raspberry Pi. Although it can be run
at any time, some of the options may have difficulties if
you have heavily customised your installation.\
" 20 70 1
}

get_can_expand() {
  ROOT_PART=$(mount | sed -n 's|^/dev/\(.*\) on / .*|\1|p')

  PART_NUM=${ROOT_PART#mmcblk0p}
  if [ "$PART_NUM" = "$ROOT_PART" ]; then
    echo 1
    exit
  fi

  if [ "$PART_NUM" -ne 2 ]; then
    echo 1
    exit
  fi

  LAST_PART_NUM=$(parted /dev/mmcblk0 -ms unit s p | tail -n 1 | cut -f 1 -d:)
  if [ $LAST_PART_NUM -ne $PART_NUM ]; then
    echo 1
    exit
  fi
  echo 0
}

do_expand_rootfs() {
  ROOT_PART=$(mount | sed -n 's|^/dev/\(.*\) on / .*|\1|p')

  PART_NUM=${ROOT_PART#mmcblk0p}
  if [ "$PART_NUM" = "$ROOT_PART" ]; then
    whiptail --msgbox "$ROOT_PART is not an SD card. Don't know how to expand" 20 60 2
    return 0
  fi

  # NOTE: the NOOBS partition layout confuses parted. For now, let's only
  # agree to work with a sufficiently simple partition layout
  if [ "$PART_NUM" -ne 2 ]; then
    whiptail --msgbox "Your partition layout is not currently supported by this tool. You are probably using NOOBS, in which case your root filesystem is already expanded anyway." 20 60 2
    return 0
  fi

  LAST_PART_NUM=$(parted /dev/mmcblk0 -ms unit s p | tail -n 1 | cut -f 1 -d:)
  if [ $LAST_PART_NUM -ne $PART_NUM ]; then
    whiptail --msgbox "$ROOT_PART is not the last partition. Don't know how to expand" 20 60 2
    return 0
  fi

  # Get the starting offset of the root partition
  PART_START=$(parted /dev/mmcblk0 -ms unit s p | grep "^${PART_NUM}" | cut -f 2 -d: | sed 's/[^0-9]//g')
  [ "$PART_START" ] || return 1
  # Return value will likely be error for fdisk as it fails to reload the
  # partition table because the root fs is mounted
  fdisk /dev/mmcblk0 <<EOF
p
d
$PART_NUM
n
p
$PART_NUM
$PART_START

p
w
EOF
  ASK_TO_REBOOT=1

  # now set up an init.d script
cat <<EOF > /etc/init.d/resize2fs_once &&
#!/bin/sh
### BEGIN INIT INFO
# Provides:          resize2fs_once
# Required-Start:
# Required-Stop:
# Default-Start: 3
# Default-Stop:
# Short-Description: Resize the root filesystem to fill partition
# Description:
### END INIT INFO

. /lib/lsb/init-functions

case "\$1" in
  start)
    log_daemon_msg "Starting resize2fs_once" &&
    resize2fs /dev/$ROOT_PART &&
    update-rc.d resize2fs_once remove &&
    rm /etc/init.d/resize2fs_once &&
    log_end_msg \$?
    ;;
  *)
    echo "Usage: \$0 start" >&2
    exit 3
    ;;
esac
EOF
  chmod +x /etc/init.d/resize2fs_once &&
  update-rc.d resize2fs_once defaults &&
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "Root partition has been resized.\nThe filesystem will be enlarged upon the next reboot" 20 60 2
  fi
}

set_config_var() {
  lua - "$1" "$2" "$3" <<EOF > "$3.bak"
local key=assert(arg[1])
local value=assert(arg[2])
local fn=assert(arg[3])
local file=assert(io.open(fn))
local made_change=false
for line in file:lines() do
  if line:match("^#?%s*"..key.."=.*$") then
    line=key.."="..value
    made_change=true
  end
  print(line)
end

if not made_change then
  print(key.."="..value)
end
EOF
mv "$3.bak" "$3"
}

clear_config_var() {
  lua - "$1" "$2" <<EOF > "$2.bak"
local key=assert(arg[1])
local fn=assert(arg[2])
local file=assert(io.open(fn))
for line in file:lines() do
  if line:match("^%s*"..key.."=.*$") then
    line="#"..line
  end
  print(line)
end
EOF
mv "$2.bak" "$2"
}

get_config_var() {
  lua - "$1" "$2" <<EOF
local key=assert(arg[1])
local fn=assert(arg[2])
local file=assert(io.open(fn))
local found=false
for line in file:lines() do
  local val = line:match("^%s*"..key.."=(.*)$")
  if (val ~= nil) then
    print(val)
    found=true
    break
  end
end
if not found then
   print(0)
end
EOF
}

get_overscan() {
  OVS=$(get_config_var disable_overscan $CONFIG)
  if [ $OVS -eq 1 ]; then
    echo 1
  else
    echo 0
  fi
}

do_overscan() {
  DEFAULT=--defaultno
  CURRENT=0
  if [ $(get_overscan) -eq 0 ]; then
      DEFAULT=
      CURRENT=1
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like to enable compensation for displays with overscan?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq $CURRENT ]; then
    ASK_TO_REBOOT=1
  fi
  if [ $RET -eq 0 ] ; then
    set_config_var disable_overscan 0 $CONFIG
    STATUS=enabled
  elif [ $RET -eq 1 ]; then
    sed $CONFIG -i -e "s/^overscan_/#overscan_/"
    set_config_var disable_overscan 1 $CONFIG
    STATUS=disabled
  else
    return $RET
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "Display overscan compensation is $STATUS" 20 60 1
  fi
}

get_pixdub() {
  if is_pi ; then
    FBW=$(get_config_var framebuffer_width $CONFIG)
    if [ $FBW -eq 0 ]; then
      echo 1
    else
      echo 0
    fi
  else
    if [ -e /etc/profile.d/pd.sh ] ; then
      echo 0
    else
      echo 1
    fi
  fi
}

is_number() {
  case $1 in
    ''|*[!0-9]*) return 0 ;;
    *) return 1 ;;
  esac
}

do_pixdub() {
  DEFAULT=--defaultno
  CURRENT=0
  if [ $(get_pixdub) -eq 0 ]; then
      DEFAULT=
      CURRENT=1
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like to enable pixel doubling?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if is_pi ; then
    if [ $RET -eq 0 ] ; then
	  XVAL=$(xrandr 2>&1 | grep current | cut -f2 -d, | cut -f3 -d' ')
	  YVAL=$(xrandr 2>&1 | grep current | cut -f2 -d, | cut -f5 -d' ')
	  if is_number $XVAL || is_number $YVAL ; then
        if [ "$INTERACTIVE" = True ]; then
          whiptail --msgbox "Could not read current screen dimensions - unable to enable pixel doubling" 20 60 1
        fi
	    return 1
	  fi
	  NEWX=`expr $XVAL / 2`
	  NEWY=`expr $YVAL / 2`
      set_config_var framebuffer_width $NEWX $CONFIG
      set_config_var framebuffer_height $NEWY $CONFIG
      set_config_var scaling_kernel 8 $CONFIG
      STATUS=enabled
    elif [ $RET -eq 1 ]; then
      clear_config_var framebuffer_width $CONFIG
      clear_config_var framebuffer_height $CONFIG
      clear_config_var scaling_kernel $CONFIG
      STATUS=disabled
    else
      return $RET
    fi
  else
    if [ -e /etc/profile.d/pd.sh ] ; then
      rm /etc/profile.d/pd.sh
    fi
    if [ $RET -eq 0 ] ; then
      DEV=$(xrandr | grep -w connected | cut -f1 -d' ')
      for item in $DEV
      do
        echo xrandr --output $item --scale 0.5x0.5 >> /etc/profile.d/pd.sh
      done
      STATUS=enabled
    elif [ $RET -eq 1 ]; then
      STATUS=disabled
    else
      return $RET
    fi
  fi
  if [ $RET -eq $CURRENT ]; then
    ASK_TO_REBOOT=1
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "Pixel doubling is $STATUS" 20 60 1
  fi
}

do_change_pass() {
  whiptail --msgbox "You will now be asked to enter a new password for the $SUDO_USER user" 20 60 1
  passwd $SUDO_USER &&
  whiptail --msgbox "Password changed successfully" 20 60 1
}

do_configure_keyboard() {
  printf "Reloading keymap. This may take a short while\n"
  if [ "$INTERACTIVE" = True ]; then
    dpkg-reconfigure keyboard-configuration
  else
    local KEYMAP="$1"
    sed -i /etc/default/keyboard -e "s/^XKBLAYOUT.*/XKBLAYOUT=\"$KEYMAP\"/"
    dpkg-reconfigure -f noninteractive keyboard-configuration
  fi
  invoke-rc.d keyboard-setup start
  setsid sh -c 'exec setupcon -k --force <> /dev/tty1 >&0 2>&1'
  udevadm trigger --subsystem-match=input --action=change
  return 0
}

do_change_locale() {
  if [ "$INTERACTIVE" = True ]; then
    dpkg-reconfigure locales
  else
    local LOCALE="$1"
    if ! LOCALE_LINE="$(grep "^$LOCALE " /usr/share/i18n/SUPPORTED)"; then
      return 1
    fi
    local ENCODING="$(echo $LOCALE_LINE | cut -f2 -d " ")"
    echo "$LOCALE $ENCODING" > /etc/locale.gen
    sed -i "s/^\s*LANG=\S*/LANG=$LOCALE/" /etc/default/locale
    dpkg-reconfigure -f noninteractive locales
  fi
}

do_change_timezone() {
  if [ "$INTERACTIVE" = True ]; then
    dpkg-reconfigure tzdata
  else
    local TIMEZONE="$1"
    if [ ! -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
      return 1;
    fi
    rm /etc/localtime
    echo "$TIMEZONE" > /etc/timezone
    dpkg-reconfigure -f noninteractive tzdata
  fi
}

get_wifi_country() {
   grep country= /etc/wpa_supplicant/wpa_supplicant.conf | cut -d "=" -f 2
}

do_wifi_country() {
  IFACE="$(list_wlan_interfaces | head -n 1)"
  if [ -z "$IFACE" ]; then
    if [ "$INTERACTIVE" = True ]; then
      whiptail --msgbox "No wireless interface found" 20 60
    fi
    return 1
  fi

  if ! wpa_cli -i "$IFACE" status > /dev/null 2>&1; then
    if [ "$INTERACTIVE" = True ]; then
      whiptail --msgbox "Could not communicate with wpa_supplicant" 20 60
    fi
    return 1
  fi

  oIFS="$IFS"
  if [ "$INTERACTIVE" = True ]; then
    IFS="/"
    value=$(cat /usr/share/zoneinfo/iso3166.tab | tail -n +26 | tr '\t' '/' | tr '\n' '/')
    COUNTRY=$(whiptail --menu "Select the country in which the Pi is to be used" 20 60 10 ${value} 3>&1 1>&2 2>&3)
    IFS=$oIFS
  else
    COUNTRY=$1
    true
  fi
  if [ $? -eq 0 ];then
    wpa_cli -i "$IFACE" set country "$COUNTRY"
    if ! iw reg set "$COUNTRY" 2> /dev/null; then
        ASK_TO_REBOOT=1
    fi
    if [ -f /run/wifi-country-unset ] && hash rfkill 2> /dev/null; then
        rfkill unblock wifi
    fi
    if [ "$INTERACTIVE" = True ]; then
        whiptail --msgbox "Wi-fi country set to $COUNTRY" 20 60 1
    fi
    wpa_cli -i "$IFACE" save_config > /dev/null 2>&1
  fi
}

get_hostname() {
    cat /etc/hostname | tr -d " \t\n\r"
}

do_hostname() {
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "\
Please note: RFCs mandate that a hostname's labels \
may contain only the ASCII letters 'a' through 'z' (case-insensitive),
the digits '0' through '9', and the hyphen.
Hostname labels cannot begin or end with a hyphen.
No other symbols, punctuation characters, or blank spaces are permitted.\
" 20 70 1
  fi
  CURRENT_HOSTNAME=`cat /etc/hostname | tr -d " \t\n\r"`
  if [ "$INTERACTIVE" = True ]; then
    NEW_HOSTNAME=$(whiptail --inputbox "Please enter a hostname" 20 60 "$CURRENT_HOSTNAME" 3>&1 1>&2 2>&3)
  else
    NEW_HOSTNAME=$1
    true
  fi
  if [ $? -eq 0 ]; then
    echo $NEW_HOSTNAME > /etc/hostname
    sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
    ASK_TO_REBOOT=1
  fi
}

do_memory_split() { # Memory Split
  if [ -e /boot/start_cd.elf ]; then
    # New-style memory split setting
    ## get current memory split from /boot/config.txt
    arm=$(vcgencmd get_mem arm | cut -d '=' -f 2 | cut -d 'M' -f 1)
    gpu=$(vcgencmd get_mem gpu | cut -d '=' -f 2 | cut -d 'M' -f 1)
    tot=$(($arm+$gpu))
    if [ $tot -gt 512 ]; then
      CUR_GPU_MEM=$(get_config_var gpu_mem_1024 $CONFIG)
    elif [ $tot -gt 256 ]; then
      CUR_GPU_MEM=$(get_config_var gpu_mem_512 $CONFIG)
    else
      CUR_GPU_MEM=$(get_config_var gpu_mem_256 $CONFIG)
    fi
    if [ -z "$CUR_GPU_MEM" ] || [ $CUR_GPU_MEM = "0" ]; then
      CUR_GPU_MEM=$(get_config_var gpu_mem $CONFIG)
    fi
    [ -z "$CUR_GPU_MEM" ] || [ $CUR_GPU_MEM = "0" ] && CUR_GPU_MEM=64
    ## ask users what gpu_mem they want
    if [ "$INTERACTIVE" = True ]; then
      NEW_GPU_MEM=$(whiptail --inputbox "How much memory (MB) should the GPU have?  e.g. 16/32/64/128/256" \
        20 70 -- "$CUR_GPU_MEM" 3>&1 1>&2 2>&3)
    else
      NEW_GPU_MEM=$1
      true
    fi
    if [ $? -eq 0 ]; then
      if [ $(get_config_var gpu_mem_1024 $CONFIG) != "0" ] || [ $(get_config_var gpu_mem_512 $CONFIG) != "0" ] || [ $(get_config_var gpu_mem_256 $CONFIG) != "0" ]; then
        if [ "$INTERACTIVE" = True ]; then
          whiptail --msgbox "Device-specific memory settings were found. These have been cleared." 20 60 2
        fi
        clear_config_var gpu_mem_1024 $CONFIG
        clear_config_var gpu_mem_512 $CONFIG
        clear_config_var gpu_mem_256 $CONFIG
      fi
      set_config_var gpu_mem "$NEW_GPU_MEM" $CONFIG
      ASK_TO_REBOOT=1
    fi
  else # Old firmware so do start.elf renaming
    get_current_memory_split
    MEMSPLIT=$(whiptail --menu "Set memory split.\n$MEMSPLIT_DESCRIPTION" 20 60 10 \
      "240" "240MiB for ARM, 16MiB for VideoCore" \
      "224" "224MiB for ARM, 32MiB for VideoCore" \
      "192" "192MiB for ARM, 64MiB for VideoCore" \
      "128" "128MiB for ARM, 128MiB for VideoCore" \
      3>&1 1>&2 2>&3)
    if [ $? -eq 0 ]; then
      set_memory_split ${MEMSPLIT}
      ASK_TO_REBOOT=1
    fi
  fi
}

get_current_memory_split() {
  AVAILABLE_SPLITS="128 192 224 240"
  MEMSPLIT_DESCRIPTION=""
  for SPLIT in $AVAILABLE_SPLITS;do
    if [ -e /boot/arm${SPLIT}_start.elf ] && cmp /boot/arm${SPLIT}_start.elf /boot/start.elf >/dev/null 2>&1;then
      CURRENT_MEMSPLIT=$SPLIT
      MEMSPLIT_DESCRIPTION="Current: ${CURRENT_MEMSPLIT}MiB for ARM, $((256 - $CURRENT_MEMSPLIT))MiB for VideoCore"
      break
    fi
  done
}

set_memory_split() {
  cp -a /boot/arm${1}_start.elf /boot/start.elf
  sync
}

do_overclock() {
  if ! is_pione && ! is_pitwo; then
    whiptail --msgbox "This Pi cannot be overclocked." 20 60 2
    return 1
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "\
Be aware that overclocking may reduce the lifetime of your
Raspberry Pi. If overclocking at a certain level causes
system instability, try a more modest overclock. Hold down
shift during boot to temporarily disable overclock.
See http://elinux.org/RPi_Overclocking for more information.\
" 20 70 1
   if is_pione; then
    OVERCLOCK=$(whiptail --menu "Choose overclock preset" 20 60 10 \
      "None" "700MHz ARM, 250MHz core, 400MHz SDRAM, 0 overvolt" \
      "Modest" "800MHz ARM, 250MHz core, 400MHz SDRAM, 0 overvolt" \
      "Medium" "900MHz ARM, 250MHz core, 450MHz SDRAM, 2 overvolt" \
      "High" "950MHz ARM, 250MHz core, 450MHz SDRAM, 6 overvolt" \
      "Turbo" "1000MHz ARM, 500MHz core, 600MHz SDRAM, 6 overvolt" \
      3>&1 1>&2 2>&3)
   elif is_pitwo; then
    OVERCLOCK=$(whiptail --menu "Choose overclock preset" 20 60 10 \
      "None" "900MHz ARM, 250MHz core, 450MHz SDRAM, 0 overvolt" \
      "High" "1000MHz ARM, 500MHz core, 500MHz SDRAM, 2 overvolt" \
      3>&1 1>&2 2>&3)
   fi
  else
    OVERCLOCK=$1
    true
  fi
  if [ $? -eq 0 ]; then
    case "$OVERCLOCK" in
      None)
        clear_overclock
        ;;
      Modest)
        set_overclock Modest 800 250 400 0
        ;;
      Medium)
        set_overclock Medium 900 250 450 2
        ;;
      High)
        if is_pione; then
          set_overclock High 950 250 450 6
        else
          set_overclock High 1000 500 500 2
        fi
        ;;
      Turbo)
        set_overclock Turbo 1000 500 600 6
        ;;
      *)
        whiptail --msgbox "Programmer error, unrecognised overclock preset" 20 60 2
        return 1
        ;;
    esac
    ASK_TO_REBOOT=1
  fi
}

set_overclock() {
  set_config_var arm_freq $2 $CONFIG &&
  set_config_var core_freq $3 $CONFIG &&
  set_config_var sdram_freq $4 $CONFIG &&
  set_config_var over_voltage $5 $CONFIG &&
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "Set overclock to preset '$1'" 20 60 2
  fi
}

clear_overclock () {
  clear_config_var arm_freq $CONFIG &&
  clear_config_var core_freq $CONFIG &&
  clear_config_var sdram_freq $CONFIG &&
  clear_config_var over_voltage $CONFIG &&
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "Set overclock to preset 'None'" 20 60 2
  fi
}

get_ssh() {
  if service ssh status | grep -q inactive; then
    echo 1
  else
    echo 0
  fi
}

do_ssh() {
  if [ -e /var/log/regen_ssh_keys.log ] && ! grep -q "^finished" /var/log/regen_ssh_keys.log; then
    whiptail --msgbox "Initial ssh key generation still running. Please wait and try again." 20 60 2
    return 1
  fi
  DEFAULT=--defaultno
  if [ $(get_ssh) -eq 0 ]; then
    DEFAULT=
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like the SSH server to be enabled?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq 0 ]; then
    update-rc.d ssh enable &&
    invoke-rc.d ssh start &&
    STATUS=enabled
  elif [ $RET -eq 1 ]; then
    update-rc.d ssh disable &&
    invoke-rc.d ssh stop &&
    STATUS=disabled
  else
    return $RET
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "The SSH server is $STATUS" 20 60 1
  fi
}

get_vnc() {
  if systemctl status vncserver-x11-serviced.service  | grep -q inactive; then
    echo 1
  else
    echo 0
  fi
}

do_vnc() {
  DEFAULT=--defaultno
  if [ $(get_vnc) -eq 0 ]; then
    DEFAULT=
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like the VNC Server to be enabled?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq 0 ]; then
    if [ ! -d /usr/share/doc/realvnc-vnc-server ] ; then
        apt -qq install realvnc-vnc-server -y
    fi
    systemctl enable vncserver-x11-serviced.service &&
    systemctl start vncserver-x11-serviced.service &&
    STATUS=enabled
  elif [ $RET -eq 1 ]; then
    systemctl disable vncserver-x11-serviced.service &&
    systemctl stop vncserver-x11-serviced.service &&
    STATUS=disabled
  else
    return $RET
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "The VNC Server is $STATUS" 20 60 1
  fi
}

get_spi() {
  if grep -q -E "^(device_tree_param|dtparam)=([^,]*,)*spi(=(on|true|yes|1))?(,.*)?$" $CONFIG; then
    echo 0
  else
    echo 1
  fi
}

do_spi() {
  DEFAULT=--defaultno
  if [ $(get_spi) -eq 0 ]; then
    DEFAULT=
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like the SPI interface to be enabled?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq 0 ]; then
    SETTING=on
    STATUS=enabled
  elif [ $RET -eq 1 ]; then
    SETTING=off
    STATUS=disabled
  else
    return $RET
  fi

  set_config_var dtparam=spi $SETTING $CONFIG &&
  if ! [ -e $BLACKLIST ]; then
    touch $BLACKLIST
  fi
  sed $BLACKLIST -i -e "s/^\(blacklist[[:space:]]*spi[-_]bcm2708\)/#\1/"
  dtparam spi=$SETTING

  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "The SPI interface is $STATUS" 20 60 1
  fi
}

get_i2c() {
  if grep -q -E "^(device_tree_param|dtparam)=([^,]*,)*i2c(_arm)?(=(on|true|yes|1))?(,.*)?$" $CONFIG; then
    echo 0
  else
    echo 1
  fi
}

do_i2c() {
  DEFAULT=--defaultno
  if [ $(get_i2c) -eq 0 ]; then
    DEFAULT=
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like the ARM I2C interface to be enabled?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq 0 ]; then
    SETTING=on
    STATUS=enabled
  elif [ $RET -eq 1 ]; then
    SETTING=off
    STATUS=disabled
  else
    return $RET
  fi

  set_config_var dtparam=i2c_arm $SETTING $CONFIG &&
  if ! [ -e $BLACKLIST ]; then
    touch $BLACKLIST
  fi
  sed $BLACKLIST -i -e "s/^\(blacklist[[:space:]]*i2c[-_]bcm2708\)/#\1/"
  sed /etc/modules -i -e "s/^#[[:space:]]*\(i2c[-_]dev\)/\1/"
  if ! grep -q "^i2c[-_]dev" /etc/modules; then
    printf "i2c-dev\n" >> /etc/modules
  fi
  dtparam i2c_arm=$SETTING
  modprobe i2c-dev

  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "The ARM I2C interface is $STATUS" 20 60 1
  fi
}

get_serial() {
  if grep -q -E "console=(serial0|ttyAMA0|ttyS0)" $CMDLINE ; then
    echo 0
  else
    echo 1
  fi
}

get_serial_hw() {
  if grep -q -E "^enable_uart=1" $CONFIG ; then
    echo 0
  elif grep -q -E "^enable_uart=0" $CONFIG ; then
    echo 1
  elif [ -e /dev/serial0 ] ; then
    echo 0
  else
    echo 1
  fi
}

do_serial() {
  DEFAULTS=--defaultno
  DEFAULTH=--defaultno
  CURRENTS=0
  CURRENTH=0
  if [ $(get_serial) -eq 0 ]; then
      DEFAULTS=
      CURRENTS=1
  fi
  if [ $(get_serial_hw) -eq 0 ]; then
      DEFAULTH=
      CURRENTH=1
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like a login shell to be accessible over serial?" $DEFAULTS 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq $CURRENTS ]; then
    ASK_TO_REBOOT=1
  fi
  if [ $RET -eq 0 ]; then
    if grep -q "console=ttyAMA0" $CMDLINE ; then
      if [ -e /proc/device-tree/aliases/serial0 ]; then
        sed -i $CMDLINE -e "s/console=ttyAMA0/console=serial0/"
      fi
    elif ! grep -q "console=ttyAMA0" $CMDLINE && ! grep -q "console=serial0" $CMDLINE ; then
      if [ -e /proc/device-tree/aliases/serial0 ]; then
        sed -i $CMDLINE -e "s/root=/console=serial0,115200 root=/"
      else
        sed -i $CMDLINE -e "s/root=/console=ttyAMA0,115200 root=/"
      fi
    fi
    set_config_var enable_uart 1 $CONFIG
    SSTATUS=enabled
    HSTATUS=enabled
  elif [ $RET -eq 1 ] || [ $RET -eq 2 ]; then
    sed -i $CMDLINE -e "s/console=ttyAMA0,[0-9]\+ //"
    sed -i $CMDLINE -e "s/console=serial0,[0-9]\+ //"
    SSTATUS=disabled
    if [ "$INTERACTIVE" = True ]; then
      whiptail --yesno "Would you like the serial port hardware to be enabled?" $DEFAULTH 20 60 2
      RET=$?
    else
      RET=$((2-$RET))
    fi
    if [ $RET -eq $CURRENTH ]; then
     ASK_TO_REBOOT=1
    fi
    if [ $RET -eq 0 ]; then
      set_config_var enable_uart 1 $CONFIG
      HSTATUS=enabled
    elif [ $RET -eq 1 ]; then
      set_config_var enable_uart 0 $CONFIG
      HSTATUS=disabled
    else
      return $RET
    fi
  else
    return $RET
  fi
  if [ "$INTERACTIVE" = True ]; then
      whiptail --msgbox "The serial login shell is $SSTATUS\nThe serial interface is $HSTATUS" 20 60 1
  fi
}

disable_raspi_config_at_boot() {
  if [ -e /etc/profile.d/raspi-config.sh ]; then
    rm -f /etc/profile.d/raspi-config.sh
    if [ -e /etc/systemd/system/getty@tty1.service.d/raspi-config-override.conf ]; then
      rm /etc/systemd/system/getty@tty1.service.d/raspi-config-override.conf
    fi
    telinit q
  fi
}

get_boot_cli() {
  if systemctl get-default | grep -q multi-user ; then
    echo 0
  else
    echo 1
  fi
}

get_autologin() {
  if [ $(get_boot_cli) -eq 0 ]; then
    # booting to CLI - check the autologin in getty or initd */
    if grep -q autologin /etc/systemd/system/getty.target.wants/getty@tty1.service ; then
      echo 0
    else
      echo 1
    fi
  else
    # booting to desktop - check the autologin for lightdm */
    if grep -q "^autologin-user=" /etc/lightdm/lightdm.conf ; then
      echo 0
    else
      echo 1
    fi
  fi
}

do_boot_behaviour() {
  if [ "$INTERACTIVE" = True ]; then
    BOOTOPT=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Boot Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
      "B1 Console" "Text console, requiring user to login" \
      "B2 Console Autologin" "Text console, automatically logged in as '$SUDO_USER' user" \
      "B3 Desktop" "Desktop GUI, requiring user to login" \
      "B4 Desktop Autologin" "Desktop GUI, automatically logged in as '$SUDO_USER' user" \
      3>&1 1>&2 2>&3)
  else
    BOOTOPT=$1
    true
  fi
  if [ $? -eq 0 ]; then
    case "$BOOTOPT" in
      B1*)
        systemctl set-default multi-user.target
        ln -fs /lib/systemd/system/getty@.service /etc/systemd/system/getty.target.wants/getty@tty1.service
        ;;
      B2*)
        systemctl set-default multi-user.target
        sed /etc/systemd/system/autologin@.service -i -e "s#^ExecStart=-/sbin/agetty --autologin [^[:space:]]*#ExecStart=-/sbin/agetty --autologin $SUDO_USER#"
        ln -fs /etc/systemd/system/autologin@.service /etc/systemd/system/getty.target.wants/getty@tty1.service
        ;;
      B3*)
        if [ -e /etc/init.d/lightdm ]; then
          systemctl set-default graphical.target
          ln -fs /lib/systemd/system/getty@.service /etc/systemd/system/getty.target.wants/getty@tty1.service
          sed /etc/lightdm/lightdm.conf -i -e "s/^autologin-user=.*/#autologin-user=/"
          disable_raspi_config_at_boot
        else
          whiptail --msgbox "Do 'sudo apt-get install lightdm' to allow configuration of boot to desktop" 20 60 2
          return 1
        fi
        ;;
      B4*)
        if [ -e /etc/init.d/lightdm ]; then
          systemctl set-default graphical.target
          ln -fs /etc/systemd/system/autologin@.service /etc/systemd/system/getty.target.wants/getty@tty1.service
          sed /etc/lightdm/lightdm.conf -i -e "s/^\(#\|\)autologin-user=.*/autologin-user=$SUDO_USER/"
          disable_raspi_config_at_boot
        else
          whiptail --msgbox "Do 'sudo apt-get install lightdm' to allow configuration of boot to desktop" 20 60 2
          return 1
        fi
        ;;
      *)
        whiptail --msgbox "Programmer error, unrecognised boot option" 20 60 2
        return 1
        ;;
    esac
    ASK_TO_REBOOT=1
  fi
}

get_boot_wait() {
  if test -e /etc/systemd/system/dhcpcd.service.d/wait.conf; then
    echo 0
  else
    echo 1
  fi
}

do_boot_wait() {
  DEFAULT=--defaultno
  if [ $(get_boot_wait) -eq 0 ]; then
    DEFAULT=
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like boot to wait until a network connection is established?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq 0 ]; then
    mkdir -p /etc/systemd/system/dhcpcd.service.d/
    cat > /etc/systemd/system/dhcpcd.service.d/wait.conf << EOF
  [Service]
  ExecStart=
  ExecStart=/usr/lib/dhcpcd5/dhcpcd -q -w
EOF
    STATUS=enabled
  elif [ $RET -eq 1 ]; then
    rm -f /etc/systemd/system/dhcpcd.service.d/wait.conf
    STATUS=disabled
  else
    return $RET
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "Waiting for network on boot is $STATUS" 20 60 1
  fi
}

get_boot_splash() {
  if is_pi ; then
    if grep -q "splash" $CMDLINE ; then
      echo 0
    else
      echo 1
    fi
  else
    if grep -q "GRUB_CMDLINE_LINUX_DEFAULT.*splash" /etc/default/grub ; then
      echo 0
    else
      echo 1
    fi
  fi
}

do_boot_splash() {
  if [ ! -e /usr/share/plymouth/themes/pix/pix.script ]; then
    if [ "$INTERACTIVE" = True ]; then
      whiptail --msgbox "The splash screen is not installed so cannot be activated" 20 60 2
    fi
    return 1
  fi
  DEFAULT=--defaultno
  if [ $(get_boot_splash) -eq 0 ]; then
    DEFAULT=
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like to show the splash screen at boot?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq 0 ]; then
    if is_pi ; then
      if ! grep -q "splash" $CMDLINE ; then
        sed -i $CMDLINE -e "s/$/ quiet splash plymouth.ignore-serial-consoles/"
      fi
    else
      sed -i /etc/default/grub -e "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 quiet splash plymouth.ignore-serial-consoles\"/"
      sed -i /etc/default/grub -e "s/  \+/ /g"
      sed -i /etc/default/grub -e "s/GRUB_CMDLINE_LINUX_DEFAULT=\" /GRUB_CMDLINE_LINUX_DEFAULT=\"/"
      update-grub
    fi
    STATUS=enabled
  elif [ $RET -eq 1 ]; then
    if is_pi ; then
      if grep -q "splash" $CMDLINE ; then
        sed -i $CMDLINE -e "s/ quiet//"
        sed -i $CMDLINE -e "s/ splash//"
        sed -i $CMDLINE -e "s/ plymouth.ignore-serial-consoles//"
      fi
    else
      sed -i /etc/default/grub -e "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)quiet\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1\2\"/"
      sed -i /etc/default/grub -e "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)splash\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1\2\"/"
      sed -i /etc/default/grub -e "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)plymouth.ignore-serial-consoles\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1\2\"/"
      sed -i /etc/default/grub -e "s/  \+/ /g"
      sed -i /etc/default/grub -e "s/GRUB_CMDLINE_LINUX_DEFAULT=\" /GRUB_CMDLINE_LINUX_DEFAULT=\"/"
      update-grub
    fi
    STATUS=disabled
  else
    return $RET
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "Splash screen at boot is $STATUS" 20 60 1
  fi
}

get_rgpio() {
  if test -e /etc/systemd/system/pigpiod.service.d/public.conf; then
    echo 0
  else
    echo 1
  fi
}

do_rgpio() {
  DEFAULT=--defaultno
  if [ $(get_rgpio) -eq 0 ]; then
    DEFAULT=
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like the GPIO server to be accessible over the network?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq 0 ]; then
    mkdir -p /etc/systemd/system/pigpiod.service.d/
    cat > /etc/systemd/system/pigpiod.service.d/public.conf << EOF
  [Service]
  ExecStart=
  ExecStart=/usr/bin/pigpiod
EOF
    STATUS=enabled
  elif [ $RET -eq 1 ]; then
    rm -f /etc/systemd/system/pigpiod.service.d/public.conf
    STATUS=disabled
  else
    return $RET
  fi
  systemctl daemon-reload
  if systemctl -q is-enabled pigpiod ; then
    systemctl restart pigpiod
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "Remote access to the GPIO server is $STATUS" 20 60 1
  fi
}

get_camera() {
  CAM=$(get_config_var start_x $CONFIG)
  if [ $CAM -eq 1 ]; then
    echo 0
  else
    echo 1
  fi
}

do_camera() {
  if [ ! -e /boot/start_x.elf ]; then
    whiptail --msgbox "Your firmware appears to be out of date (no start_x.elf). Please update" 20 60 2
    return 1
  fi
  sed $CONFIG -i -e "s/^startx/#startx/"
  sed $CONFIG -i -e "s/^fixup_file/#fixup_file/"

  DEFAULT=--defaultno
  CURRENT=0
  if [ $(get_camera) -eq 0 ]; then
      DEFAULT=
      CURRENT=1
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like the camera interface to be enabled?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq $CURRENT ]; then
    ASK_TO_REBOOT=1
  fi
  if [ $RET -eq 0 ]; then
    set_config_var start_x 1 $CONFIG
    CUR_GPU_MEM=$(get_config_var gpu_mem $CONFIG)
    if [ -z "$CUR_GPU_MEM" ] || [ "$CUR_GPU_MEM" -lt 128 ]; then
      set_config_var gpu_mem 128 $CONFIG
    fi
    STATUS=enabled
  elif [ $RET -eq 1 ]; then
    set_config_var start_x 0 $CONFIG
    sed $CONFIG -i -e "s/^start_file/#start_file/"
    STATUS=disabled
  else
    return $RET
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "The camera interface is $STATUS" 20 60 1
  fi
}

get_onewire() {
  if grep -q -E "^dtoverlay=w1-gpio" $CONFIG; then
    echo 0
  else
    echo 1
  fi
}

do_onewire() {
  DEFAULT=--defaultno
  CURRENT=0
  if [ $(get_onewire) -eq 0 ]; then
    DEFAULT=
    CURRENT=1
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like the one-wire interface to be enabled?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq $CURRENT ]; then
    ASK_TO_REBOOT=1
  fi
  if [ $RET -eq 0 ]; then
    sed $CONFIG -i -e "s/^#dtoverlay=w1-gpio/dtoverlay=w1-gpio/"
    if ! grep -q -E "^dtoverlay=w1-gpio" $CONFIG; then
      printf "dtoverlay=w1-gpio\n" >> $CONFIG
    fi
    STATUS=enabled
  elif [ $RET -eq 1 ]; then
    sed $CONFIG -i -e "s/^dtoverlay=w1-gpio/#dtoverlay=w1-gpio/"
    STATUS=disabled
  else
    return $RET
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "The one-wire interface is $STATUS" 20 60 1
  fi
}

do_gldriver() {
  if [ ! -e /boot/overlays/vc4-kms-v3d.dtbo ]; then
    whiptail --msgbox "Driver and kernel not present on your system. Please update" 20 60 2
    return 1
  fi
  if [ $(dpkg -l libgl1-mesa-dri | tail -n 1 | cut -d ' ' -f 1) != "ii" ]; then
    whiptail --msgbox "libgl1-mesa-dri not found - please install" 20 60 2
    return 1
  fi
  GLOPT=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "GL Driver" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
    "G1 GL (Full KMS)" "OpenGL desktop driver with full KMS" \
    "G2 GL (Fake KMS)" "OpenGL desktop driver with fake KMS" \
    "G3 Legacy" "Original non-GL desktop driver" \
    3>&1 1>&2 2>&3)
  if [ $? -eq 0 ]; then
    case "$GLOPT" in
      G1*)
        if ! grep -q -E "^dtoverlay=vc4-kms-v3d" $CONFIG; then
          ASK_TO_REBOOT=1
        fi
        sed $CONFIG -i -e "s/^dtoverlay=vc4-fkms-v3d/#dtoverlay=vc4-fkms-v3d/"
        sed $CONFIG -i -e "s/^#dtoverlay=vc4-kms-v3d/dtoverlay=vc4-kms-v3d/"
        if ! grep -q -E "^dtoverlay=vc4-kms-v3d" $CONFIG; then
          printf "dtoverlay=vc4-kms-v3d\n" >> $CONFIG
        fi
        STATUS="The full KMS GL driver is enabled."
        ;;
      G2*)
        if ! grep -q -E "^dtoverlay=vc4-fkms-v3d" $CONFIG; then
          ASK_TO_REBOOT=1
        fi
        sed $CONFIG -i -e "s/^dtoverlay=vc4-kms-v3d/#dtoverlay=vc4-kms-v3d/"
        sed $CONFIG -i -e "s/^#dtoverlay=vc4-fkms-v3d/dtoverlay=vc4-fkms-v3d/"
        if ! grep -q -E "^dtoverlay=vc4-fkms-v3d" $CONFIG; then
          printf "dtoverlay=vc4-fkms-v3d\n" >> $CONFIG
        fi
        STATUS="The fake KMS GL driver is enabled."
        ;;
      G3*)
        if grep -q -E "^dtoverlay=vc4-f?kms-v3d" $CONFIG; then
          ASK_TO_REBOOT=1
        fi
        sed $CONFIG -i -e "s/^dtoverlay=vc4-kms-v3d/#dtoverlay=vc4-kms-v3d/"
        sed $CONFIG -i -e "s/^dtoverlay=vc4-fkms-v3d/#dtoverlay=vc4-fkms-v3d/"
        STATUS="The GL driver is disabled."
        ;;
      *)
        whiptail --msgbox "Programmer error, unrecognised boot option" 20 60 2
        return 1
        ;;
    esac
  else
    return 0
  fi
  if echo "$GLOPT" | grep -q -E "1" ; then
    if grep -q "splash" $CMDLINE ; then
      sed -i $CMDLINE -e "s/ quiet//"
      sed -i $CMDLINE -e "s/ splash//"
      sed -i $CMDLINE -e "s/ plymouth.ignore-serial-consoles//"
    fi
    sed $CONFIG -i -e "s/^gpu_mem/#gpu_mem/"
  fi
  whiptail --msgbox "$STATUS" 20 60 1
 }

get_net_names() {
  if grep -q "net.ifnames=0" $CMDLINE || [ "$(readlink -f /etc/systemd/network/99-default.link)" = "/dev/null" ] ; then
    echo 1
  else
    echo 0
  fi
}

do_net_names () {
  DEFAULT=--defaultno
  CURRENT=0
  if [ $(get_net_names) -eq 0 ]; then
    DEFAULT=
    CURRENT=1
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like to enable predictable network interface names?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq $CURRENT ]; then
    ASK_TO_REBOOT=1
  fi
  if [ $RET -eq 0 ]; then
    sed -i $CMDLINE -e "s/net.ifnames=0 *//"
    rm -f /etc/systemd/network/99-default.link
    STATUS=enabled
  elif [ $RET -eq 1 ]; then
    ln -sf /dev/null /etc/systemd/network/99-default.link
    STATUS=disabled
  else
    return $RET
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "Predictable network interface names are $STATUS" 20 60 1
  fi
 }

do_audio() {
  if [ "$INTERACTIVE" = True ]; then
    AUDIO_OUT=$(whiptail --menu "Choose the audio output" 20 60 10 \
      "0" "Auto" \
      "1" "Force 3.5mm ('headphone') jack" \
      "2" "Force HDMI" \
      3>&1 1>&2 2>&3)
  else
    AUDIO_OUT=$1
  fi
  if [ $? -eq 0 ]; then
    amixer cset numid=3 "$AUDIO_OUT"
  fi
}

do_resolution() {
  if [ "$INTERACTIVE" = True ]; then
    CMODE=$(get_config_var hdmi_mode $CONFIG)
    CGROUP=$(get_config_var hdmi_group $CONFIG)
    if [ $CMODE -eq 0 ] ; then
      CSET="Default"
    elif [ $CGROUP -eq 2 ] ; then
      CSET="DMT Mode "$CMODE
    else
      CSET="CEA Mode "$CMODE
    fi
    oIFS="$IFS"
    IFS="/"
    if tvservice -d /dev/null | grep -q Nothing ; then
      value="Default/720x480/DMT Mode 4/640x480 60Hz 4:3/DMT Mode 9/800x600 60Hz 4:3/DMT Mode 16/1024x768 60Hz 4:3/DMT Mode 85/1280x720 60Hz 16:9/DMT Mode 35/1280x1024 60Hz 5:4/DMT Mode 51/1600x1200 60Hz 4:3/DMT Mode 82/1920x1080 60Hz 16:9/"
    else
      value="Default/Monitor preferred resolution/"
      value=$value$(tvservice -m CEA | grep progressive | cut -b 12- | sed 's/mode \([0-9]\+\): \([0-9]\+\)x\([0-9]\+\) @ \([0-9]\+\)Hz \([0-9]\+\):\([0-9]\+\), clock:[0-9]\+MHz progressive/CEA Mode \1\/\2x\3 \4Hz \5:\6/' | tr '\n' '/')
      value=$value$(tvservice -m DMT | grep progressive | cut -b 12- | sed 's/mode \([0-9]\+\): \([0-9]\+\)x\([0-9]\+\) @ \([0-9]\+\)Hz \([0-9]\+\):\([0-9]\+\), clock:[0-9]\+MHz progressive/DMT Mode \1\/\2x\3 \4Hz \5:\6/' | tr '\n' '/')
    fi
    RES=$(whiptail --default-item $CSET --menu "Choose screen resolution" 20 60 10 ${value} 3>&1 1>&2 2>&3)
    STATUS=$?
    IFS=$oIFS
    if [ $STATUS -eq 0 ] ; then
      GRS=$(echo "$RES" | cut -d ' ' -f 1)
      MODE=$(echo "$RES" | cut -d ' ' -f 3)
      if [ $GRS = "Default" ] ; then
        MODE=0
      elif [ $GRS = "DMT" ] ; then
        GROUP=2
      else
        GROUP=1
      fi
    fi
  else
    GROUP=$1
    MODE=$2
    STATUS=0
  fi
  if [ $STATUS -eq 0 ]; then
    if [ $MODE -eq 0 ]; then
      clear_config_var hdmi_force_hotplug $CONFIG
      clear_config_var hdmi_group $CONFIG
      clear_config_var hdmi_mode $CONFIG
    else
      set_config_var hdmi_force_hotplug 1 $CONFIG
      set_config_var hdmi_group $GROUP $CONFIG
      set_config_var hdmi_mode $MODE $CONFIG
    fi
    if [ "$INTERACTIVE" = True ]; then
      if [ $MODE -eq 0 ] ; then
        whiptail --msgbox "The resolution is set to default" 20 60 1
      else
        whiptail --msgbox "The resolution is set to $GRS mode $MODE" 20 60 1
      fi
    fi
    if [ $MODE -eq 0 ] ; then
      TSET="Default"
    elif [ $GROUP -eq 2 ] ; then
      TSET="DMT Mode "$MODE
    else
      TSET="CEA Mode "$MODE
    fi
    if [ "$TSET" != "$CSET" ] ; then
      ASK_TO_REBOOT=1
    fi
  fi
}

list_wlan_interfaces() {
  for dir in /sys/class/net/*/wireless; do
    if [ -d "$dir" ]; then
      basename "$(dirname "$dir")"
    fi
  done
}

do_wifi_ssid_passphrase() {
  RET=0
  IFACE_LIST="$(list_wlan_interfaces)"
  IFACE="$(echo "$IFACE_LIST" | head -n 1)"

  if [ -z "$IFACE" ]; then
    if [ "$INTERACTIVE" = True ]; then
      whiptail --msgbox "No wireless interface found" 20 60
    fi
    return 1
  fi

  if ! wpa_cli -i "$IFACE" status > /dev/null 2>&1; then
    if [ "$INTERACTIVE" = True ]; then
      whiptail --msgbox "Could not communicate with wpa_supplicant" 20 60
    fi
    return 1
  fi

  if [ "$INTERACTIVE" = True ] && [ -z "$(get_wifi_country)" ]; then
    do_wifi_country
  fi

  SSID="$1"
  while [ -z "$SSID" ] && [ "$INTERACTIVE" = True ]; do
    SSID=$(whiptail --inputbox "Please enter SSID" 20 60 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
      return 0
    elif [ -z "$SSID" ]; then
      whiptail --msgbox "SSID cannot be empty. Please try again." 20 60
    fi
  done

  PASSPHRASE="$2"
  while [ "$INTERACTIVE" = True ]; do
    PASSPHRASE=$(whiptail --passwordbox "Please enter passphrase. Leave it empty if none." 20 60 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
      return 0
    else
      break
    fi
  done

  # Escape special characters for embedding in regex below
  local ssid="$(echo "$SSID" \
   | sed 's;\\;\\\\;g' \
   | sed -e 's;\.;\\\.;g' \
         -e 's;\*;\\\*;g' \
         -e 's;\+;\\\+;g' \
         -e 's;\?;\\\?;g' \
         -e 's;\^;\\\^;g' \
         -e 's;\$;\\\$;g' \
         -e 's;\/;\\\/;g' \
         -e 's;\[;\\\[;g' \
         -e 's;\];\\\];g' \
         -e 's;{;\\{;g'   \
         -e 's;};\\};g'   \
         -e 's;(;\\(;g'   \
         -e 's;);\\);g'   \
         -e 's;";\\\\\";g')"

  wpa_cli -i "$IFACE" list_networks \
   | tail -n +2 | cut -f -2 | grep -P "\t$ssid$" | cut -f1 \
   | while read ID; do
    wpa_cli -i "$IFACE" remove_network "$ID" > /dev/null 2>&1
  done

  ID="$(wpa_cli -i "$IFACE" add_network)"
  wpa_cli -i "$IFACE" set_network "$ID" ssid "\"$SSID\"" 2>&1 | grep -q "OK"
  RET=$((RET + $?))

  if [ -z "$PASSPHRASE" ]; then
    wpa_cli -i "$IFACE" set_network "$ID" key_mgmt NONE 2>&1 | grep -q "OK"
    RET=$((RET + $?))
  else
    wpa_cli -i "$IFACE" set_network "$ID" psk "\"$PASSPHRASE\"" 2>&1 | grep -q "OK"
    RET=$((RET + $?))
  fi

  if [ $RET -eq 0 ]; then
    wpa_cli -i "$IFACE" enable_network "$ID" > /dev/null 2>&1
  else
    wpa_cli -i "$IFACE" remove_network "$ID" > /dev/null 2>&1
    if [ "$INTERACTIVE" = True ]; then
      whiptail --msgbox "Failed to set SSID or passphrase" 20 60
    fi
  fi
  wpa_cli -i "$IFACE" save_config > /dev/null 2>&1

  echo "$IFACE_LIST" | while read IFACE; do
    wpa_cli -i "$IFACE" reconfigure > /dev/null 2>&1
  done

  return $RET
}

do_finish() {
  disable_raspi_config_at_boot
  if [ $ASK_TO_REBOOT -eq 1 ]; then
    whiptail --yesno "Would you like to reboot now?  Reconnect in 15 seconds." 20 60 2
    if [ $? -eq 0 ]; then # yes
      sync
      reboot
    fi
  fi
  exit 0
}

# $1 = filename, $2 = key name
get_json_string_val() {
  sed -n -e "s/^[[:space:]]*\"$2\"[[:space:]]*:[[:space:]]*\"\(.*\)\"[[:space:]]*,$/\1/p" $1
}

# TODO: This is probably broken
do_apply_os_config() {
  [ -e /boot/os_config.json ] || return 0
  NOOBSFLAVOUR=$(get_json_string_val /boot/os_config.json flavour)
  NOOBSLANGUAGE=$(get_json_string_val /boot/os_config.json language)
  NOOBSKEYBOARD=$(get_json_string_val /boot/os_config.json keyboard)

  if [ -n "$NOOBSFLAVOUR" ]; then
    printf "Setting flavour to %s based on os_config.json from NOOBS. May take a while\n" "$NOOBSFLAVOUR"

    printf "Unrecognised flavour. Ignoring\n"
  fi

  # TODO: currently ignores en_gb settings as we assume we are running in a
  # first boot context, where UK English settings are default
  case "$NOOBSLANGUAGE" in
    "en")
      if [ "$NOOBSKEYBOARD" = "gb" ]; then
        DEBLANGUAGE="" # UK english is the default, so ignore
      else
        DEBLANGUAGE="en_US.UTF-8"
      fi
      ;;
    "de")
      DEBLANGUAGE="de_DE.UTF-8"
      ;;
    "fi")
      DEBLANGUAGE="fi_FI.UTF-8"
      ;;
    "fr")
      DEBLANGUAGE="fr_FR.UTF-8"
      ;;
    "hu")
      DEBLANGUAGE="hu_HU.UTF-8"
      ;;
    "ja")
      DEBLANGUAGE="ja_JP.UTF-8"
      ;;
    "nl")
      DEBLANGUAGE="nl_NL.UTF-8"
      ;;
    "pt")
      DEBLANGUAGE="pt_PT.UTF-8"
      ;;
    "ru")
      DEBLANGUAGE="ru_RU.UTF-8"
      ;;
    "zh_CN")
      DEBLANGUAGE="zh_CN.UTF-8"
      ;;
    *)
      printf "Language '%s' not handled currently. Run sudo rpi_torbox to set up" "$NOOBSLANGUAGE"
      ;;
  esac

  if [ -n "$DEBLANGUAGE" ]; then
    printf "Setting language to %s based on os_config.json from NOOBS. May take a while\n" "$DEBLANGUAGE"
    do_change_locale "$DEBLANGUAGE"
  fi

  if [ -n "$NOOBSKEYBOARD" -a "$NOOBSKEYBOARD" != "gb" ]; then
    printf "Setting keyboard layout to %s based on os_config.json from NOOBS. May take a while\n" "$NOOBSKEYBOARD"
    do_configure_keyboard "$NOOBSKEYBOARD"
  fi
  return 0
}

nonint() {
  "$@"
}

# RPi Torrent Box functions
# by DarkSlave
# Rev 1.0 7/27/2018
#

do_first_time_boot_menu() {
  echo -e "\e[0;96m> Creating install log file at \e[0;92m/var/log/rpi-config_install.log \e[0m" &&
  do_with_root touch /var/log/rpi-config_install.log
  do_with_root chown pi:pi /var/log/rpi-config_install.log
  echo -e '`date`\nCreating install log file at /var/log/rpi-config_install.log' >> /var/log/rpi-config_install.log &&
  echo -e '\nFirst boot initialization for torrent box installation\n'`date` >> /var/log/rpi-config_install.log &&
  while true; do
    FUN=$(whiptail --title "Raspberry Pi Torrent Box Configuration Menu (raspi-torbox)" --menu "First Time Boot Changes (Reboot Required at End)" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
      "F1 Swap File" "Make Swap File 2.0Gb Size" \
      "F2 Expand Filesystem" "Ensures that all of the SD card storage is available to the OS" \
      "F3 Change User Password" "Change password for the current user" \
      "F4 LAN Settings 'eth0'" "LAN Settings for interface 'eth0': hostname, static IP, gateway router, ssh port" \
      "F5 Wi-fi Setup" "Wi-fi SSID, Passphrase, and Country setting" \
      "F6 Localisation Options" "Set up language and regional settings to match your location" \
      "F9 Reboot RPi" "Reboot RPi to take effect" \
      3>&1 1>&2 2>&3)
      RET=$?
      if [ $RET -eq 1 ]; then
        do_raspi_config_menu
      elif [ $RET -eq 0 ]; then
        case "$FUN" in
          F1\ *) echo -e '\nSwap File activate\n'`date` >> /var/log/rpi-config_install.log && do_swap_change ;;
          F2\ *) echo -e '\nExpand Filesystem activate\n'`date` >> /var/log/rpi-config_install.log && do_expand_rootfs ;;  # raspi-config
          F3\ *) echo -e '\nChange User Password activate\n'`date` >> /var/log/rpi-config_install.log && do_change_pass ;;  # raspi-config
          F4\ *) echo -e '\nLAN Settings activate\n'`date` >> /var/log/rpi-config_install.log && do_lan_eth0_rpi_settings ;;
          F5\ *) echo -e '\nWi-fi Setup activate\n'`date` >> /var/log/rpi-config_install.log && do_wifi_ssid_passphrase && do_wifi_country ;;  # raspi-config
          F6\ *) echo -e '\nLocalisation Options activate\n'`date` >> /var/log/rpi-config_install.log && do_change_locale && do_change_timezone && do_configure_keyboard ;; # raspi-config
          F9\ *) echo -e '\nFirst reboot activate\n'`date` >> /var/log/rpi-config_install.log && do_reboot ;;
          *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
        esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
    else
        return 0
      fi
    done
}

do_swap_change() {
  do_with_root sed -i 's/CONF_SWAPSIZE=100/CONF_SWAPSIZE=1024/' /etc/dphys-swapfile >> /var/log/rpi-config_install.log 2>&1 &&
  do_with_root dphys-swapfile setup >> /var/log/rpi-config_install.log 2>&1 &&
  do_with_root dphys-swapfile swapon >> /var/log/rpi-config_install.log 2>&1 &&
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "SWAPFILE size has been resized to 1GB.\nThe swapfile will be enlarged upon the next reboot." 20 60 2
  fi
  ASK_TO_REBOOT=1
}

do_lan_eth0_rpi_settings() {
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "Several custom settings will be asked; please make note of them. Hostname, Static IP address, Gateway/Router IP, SSH port." 20 70 1
  fi
  # HOSTNAME
  CURRENT_HOSTNAME=`cat /etc/hostname | tr -d " \t\n\r"`
  if [ "$INTERACTIVE" = True ]; then
    NEW_HOSTNAME=$(whiptail --inputbox "Please enter a hostname (ie: RPiTorBox)" 20 60 "$CURRENT_HOSTNAME" 3>&1 1>&2 2>&3)
  else
    NEW_HOSTNAME=$1
    true
  fi
  # STATIC IP
  if [ "$INTERACTIVE" = True ]; then
    NEW_STATICIP=$(whiptail --inputbox "Please enter a STATIC IP (ie: 192.168.0.60)" 20 60 3>&1 1>&2 2>&3)
  else
    NEW_STATICIP=$1
    true
  fi
  # GATEWAY/ROUTER
  if [ "$INTERACTIVE" = True ]; then
    NEW_ROUTER=$(whiptail --inputbox "Please enter your Gateway/Router IP (ie: 192.168.0.1)" 20 60 3>&1 1>&2 2>&3)
  else
    NEW_ROUTER=$1
    true
  fi
  # SSH PORT
  if [ "$INTERACTIVE" = True ]; then
    NEW_SSH=$(whiptail --inputbox "Please enter the SSH port (ie: 2260)" 20 60 3>&1 1>&2 2>&3)
  else
    NEW_SSH=$1
    true
  fi
  # DATA OUTPUT FOR HOSTNAME, STATICIP, ROUTER, SSH PORT
  if [ $? -eq 0 ]; then
    echo $NEW_HOSTNAME > /etc/hostname
    sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
    echo '# Static IP Configuration by RPiTorBox' >> /etc/dhcpcd.conf
    echo interface eth0 >> /etc/dhcpcd.conf
    echo static ip_address=$NEW_STATICIP/24 >> /etc/dhcpcd.conf
    echo '#static ip6_address=fd51:42f8:caae:d92e::ff/64' >> /etc/dhcpcd.conf
    echo static routers=$NEW_ROUTER >> /etc/dhcpcd.conf
    echo static domain_name_servers=$NEW_ROUTER 8.8.8.8 fd51:42f8:caae:d92e::1 >> /etc/dhcpcd.conf
    sed -i "s/#   Port 22/   Port $NEW_SSH/" /etc/ssh/ssh_config
    sed -i "s/#Port 22/Port $NEW_SSH/" /etc/ssh/sshd_config
    ASK_TO_REBOOT=1
  fi
}

do_reboot() {
  if [ $ASK_TO_REBOOT -eq 1 ]; then
    whiptail --yesno "Please reboot the system for changes to take effect.	Would you like to reboot now?  Reconnect in 15 seconds." 20 60 2
    if [ $? -eq 0 ]; then # yes
      sync
      reboot
    fi
  fi
  return 0
}

do_exit() {
    if [ $ASK_TO_REBOOT -eq 1 ]; then
    whiptail --yesno "Would you like to reboot now?  Reconnect in 15 seconds." 20 60 2
    if [ $? -eq 0 ]; then # yes
      sync
      reboot
    fi
  fi
  exit 0
}

do_update() {
  echo -e "\e[0;96m\n> Updating package(s) and apt repositories... \e[0m\n" &&
  apt-get -qq update &&
  # apt-get -qq install raspi-config -y &&
  # echo -e "\e[0;96m> Sleeping 5 seconds before reloading raspi-config\e[0m\n" &&
  sleep 5 &&
  return 0
}

do_upgrade() {
  echo -e "\e[0;96m\n> Upgrading package(s) and application(s)... \e[0m\n" &&
  do_with_root apt-get -qq upgrade -y &&
  # echo -e "\e[0;96m> Sleeping 5 seconds before reloading raspi-config\e[0m\n" &&
  sleep 5 &&
  return 0
}

do_raspi_config_menu() {
  if [ "$INTERACTIVE" = True ]; then
    [ -e $CONFIG ] || touch $CONFIG
    calc_wt_size
    if is_pi ; then
        FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --backtitle "$(cat /proc/device-tree/model)" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
          "1 Change User Password" "Change password for the current user" \
          "2 Network Options" "Configure network settings" \
          "3 Boot Options" "Configure options for start-up" \
          "4 Localisation Options" "Set up language and regional settings to match your location" \
          "5 Interfacing Options" "Configure connections to peripherals" \
          "6 Overclock" "Configure overclocking for your Pi" \
          "7 Advanced Options" "Configure advanced settings" \
          "8 Update" "Update this tool to the latest version" \
          "9 About raspi-config" "Information about this configuration tool" \
		  3>&1 1>&2 2>&3)
      else
        FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
          "1 Change User Password" "Change password for the current user" \
          "2 Network Options" "Configure network settings" \
          "3 Boot Options" "Configure options for start-up" \
          "4 Localisation Options" "Set up language and regional settings to match your location" \
          "5 SSH" "Enable/Disable remote command line access to your PC using SSH" \
          "6 Pixel Doubling" "Enable/Disable 2x2 pixel mapping" \
          "8 Update" "Update this tool to the latest version" \
          "9 About raspi-config" "Information about this configuration tool" \
          3>&1 1>&2 2>&3)
    fi
      RET=$?
      if [ $RET -eq 1 ]; then
        return 0
      elif [ $RET -eq 0 ]; then
        if is_pi ; then
          case "$FUN" in
            1\ *) do_change_pass ;;
            2\ *) do_network_menu ;;
            3\ *) do_boot_menu ;;
            4\ *) do_internationalisation_menu ;;
            5\ *) do_interface_menu ;;
            6\ *) do_overclock ;;
            7\ *) do_advanced_menu ;;
            8\ *) do_update ;;
            9\ *) do_about ;;
            *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
          esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
        else
          case "$FUN" in
            1\ *) do_change_pass ;;
            2\ *) do_network_menu ;;
            3\ *) do_boot_menu ;;
            4\ *) do_internationalisation_menu ;;
            5\ *) do_ssh ;;
            6\ *) do_pixdub ;;
            8\ *) do_update ;;
            9\ *) do_about ;;
            *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
          esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
        fi
      fi
  fi
}

do_torbox_requirement_packages() {
  echo -e '\nDownload and installation of required packages, create folders, and install log file\n'`date` >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;93m\n> Download and installation of required packages, create folders, and install log file \e[0m\n" &&
  cd ~

  # git
  echo -e '\nDownloading and installing package(s):  git' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Downloading and installing package(s):\e[0;92m  git \e[0m" &&
  do_with_root apt-get install git git-core -y >> /var/log/rpi-config_install.log 2>&1 &&

  # dirmngr
  echo -e '\nDownloading and installing package(s):  apt-transport-https dirmngr' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Downloading and installing package(s):\e[0;92m  apt-transport-https dirmngr \e[0m"
  do_with_root apt-get install apt-transport-https dirmngr -y >> /var/log/rpi-config_install.log 2>&1 &&
  echo -e "\e[0;96m> Requesting package key:\e[0;92m  mono-project/repo \e[0m" &&
  do_with_root apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF >> /var/log/rpi-config_install.log 2>&1 &&
  echo "deb https://download.mono-project.com/repo/debian stable-raspbianstretch main" | sudo tee /etc/apt/sources.list.d/mono-official-stable.list >> /var/log/rpi-config_install.log 2>&1 &&
  echo -e "\e[0;96m> Package(s) Update Required \e[0m" &&
  do_with_root apt-get update -y >> /var/log/rpi-config_install.log 2>&1 &&

  # mono
  echo -e '\nDownloading and installing:  mono-devel' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Downloading and installing package(s):\e[0;92m  mono-devel \e[0m" &&
  do_with_root apt-get install mono-devel -y >> /var/log/rpi-config_install.log 2>&1

  # libcurl
  echo -e '\nDownloading and installing package(s):  libcurl4-openssl-dev' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Downloading and installing package(s):\e[0;92m  libcurl4-openssl-dev \e[0m" &&
  do_with_root apt-get install libcurl4-openssl-dev -y >> /var/log/rpi-config_install.log 2>&1 &&

  # mediainfo
  echo -e '\nDownloading and installing package(s):  mediainfo' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Downloading and installing package(s):\e[0;92m  mediainfo \e[0m" &&
  do_with_root apt-get install mediainfo -y >> /var/log/rpi-config_install.log 2>&1 &&
  echo -e "\e[0;96m> Package(s) Update/Upgrade Required \e[0m" &&
  do_with_root apt-get upgrade -y >> /var/log/rpi-config_install.log 2>&1 &&

  ASK_TO_REBOOT=1
}

do_torbox_directories() {
  echo -e '\nCreating directoies for Downloads, Music, Videos, Temp\n'`date` >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m\n> Creating directories for:\e[0;92m  Downloads, Music, Videos and Temp \e[0m\n" &&
  cd ~
  mkdir -m777 Downloads
  mkdir -m777 Music
  mkdir -m777 Videos
  mkdir -m777 Temp
}

do_torbox_programs() {
  echo -e '\nDownload and installation of torrent box programs\n'`date` >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;93m\n> Download and installation of torrent box programs \e[0m\n" &&
  cd ~

  # OpenVPN:  program
  cd ~
  echo -e '\nDownloading and installing program:  OpenVPN' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Downloading and installing program:\e[0;92m  OpenVPN \e[0m" &&
  do_with_root apt-get install openvpn -y >> /var/log/rpi-config_install.log 2>&1 &&

  # Deluge:  program
  echo -e '\nDownloading and installing program:  Deluge' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Downloading and installing program:\e[0;92m  Deluge \e[0m" &&
  do_with_root touch /var/log/deluged.log >> /var/log/rpi-config_install.log 2>&1 &&
  do_with_root touch /var/log/deluge-web.log >> /var/log/rpi-config_install.log 2>&1 &&
  do_with_root chown pi:pi /var/log/deluge* >> /var/log/rpi-config_install.log 2>&1 &&
  do_with_root apt-get install deluged -y >> /var/log/rpi-config_install.log 2>&1 &&
  do_with_root apt-get install deluge-webui -y >> /var/log/rpi-config_install.log 2>&1 &&
  do_with_root apt-get install deluge-console -y >> /var/log/rpi-config_install.log 2>&1 &&

  # Deluge:  services
  echo -e '\nCreating service for:  Deluge' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Creating service for:\e[0;92m  Deluge \e[0m" &&
  cd ~
  cat > deluge.service << EOF
[Unit]
Description=Deluge Bittorrent Client Daemon
After=network-online.target

[Service]
Type=simple
User=root
Group=root
UMask=000
ExecStart=/usr/bin/deluged -d
Restart=on-failure
# Configures the time to wait before service is stopped forcefully.
TimeoutStopSec=300

[Install]
WantedBy=multi-user.target
EOF
  do_with_root mv deluge.service /lib/systemd/system/deluge.service

  echo -e '\nCreating service for:  Deluge-Web' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Creating service for:\e[0;92m  Deluge-Web \e[0m" &&
  cd ~
  cat > deluge-web.service << EOF
[Unit]
Description=Deluge Bittorrent Client Web Interface
After=network-online.target

[Service]
Type=simple
User=root
Group=root
UMask=000
ExecStart=/usr/bin/deluge-web
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
  do_with_root mv deluge-web.service /lib/systemd/system/deluge-web.service

  echo -e '\nStarting service:  Deluge + Deluge-Web' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Starting service:\e[0;92m  Deluge + Deluge-Web \e[0m" &&
  do_with_root systemctl enable deluge >> /var/log/rpi-config_install.log 2>&1 &&
  do_with_root systemctl start deluge >> /var/log/rpi-config_install.log 2>&1 &&
  do_with_root systemctl enable deluge-web >> /var/log/rpi-config_install.log 2>&1 &&
  do_with_root systemctl start deluge-web >> /var/log/rpi-config_install.log 2>&1 &&

  # Jackett:  program
  echo -e '\nDownloading and installing program:  Jackett' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Downloading and installing program:\e[0;92m  Jackett \e[0m" &&
  cd ~/Downloads
  wget https://github.com/Jackett/Jackett/releases/download/v0.9.41/Jackett.Binaries.Mono.tar.gz >> /var/log/rpi-config_install.log 2>&1 &&
  do_with_root tar -zxf Jackett.Binaries.Mono.tar.gz --directory /opt/ >> /var/log/rpi-config_install.log 2>&1 &&
  do_with_root chown -Rh pi:pi /opt/Jackett >> /var/log/rpi-config_install.log 2>&1 &&

  # Jackett:  service
  echo -e '\nCreating service for:  Jackett' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Creating service for:\e[0;92m  Jackett \e[0m" &&
  cd ~
  cat > jackett.service << EOF
[Unit]
Description=Jackett Daemon
After=network.target

[Service]
User=pi
Restart=always
RestartSec=5
Type=simple
ExecStart=/usr/bin/mono --debug /opt/Jackett/JackettConsole.exe --NoRestart
TimeoutStopSec=20

[Install]
WantedBy=multi-user.target
EOF
  do_with_root mv jackett.service /lib/systemd/system/jackett.service

  echo -e '\nStarting service:  Jackett' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Starting service:\e[0;92m  Jackett \e[0m" &&
  do_with_root systemctl enable jackett >> /var/log/rpi-config_install.log 2>&1 &&
  do_with_root systemctl start jackett >> /var/log/rpi-config_install.log 2>&1 &&

  # Sonarr:  program
  echo -e '\nDownloading and installing program:  Sonarr' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Requesting package key:\e[0;92m  Sonarr \e[0m" &&
  sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys FDA5DFFC >> /var/log/rpi-config_install.log 2>&1 &&
  echo -e "\e[0;96m> Adding package to sources.list for:\e[0;92m  Sonarr \e[0m" &&
  echo "deb http://apt.sonarr.tv/ master main" | sudo tee /etc/apt/sources.list.d/sonarr.list >> /var/log/rpi-config_install.log 2>&1 &&
  echo -e '\nPackage(s) Update Required'  >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Package(s) Update Required \e[0m" &&
  do_with_root apt-get update -y >> /var/log/rpi-config_install.log 2>&1 &&
  echo -e "\e[0;96m> Downloading and installing program:\e[0;92m  Sonarr \e[0m" &&
  do_with_root apt-get install nzbdrone -y >> /var/log/rpi-config_install.log 2>&1 &&
  do_with_root chown -Rh pi:pi /opt/NzbDrone >> /var/log/rpi-config_install.log 2>&1 &&

  # Sonarr:  sevice
  echo -e '\nCreating service for:  Sonarr' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Creating service for:\e[0;92m  Sonarr \e[0m" &&
  cd ~
  cat > sonarr.service << EOF
[Unit]
Description=Sonarr Daemon
After=syslog.target network.target

[Service]
User=pi
Group=pi
Type=simple
ExecStart=/usr/bin/mono /opt/NzbDrone/NzbDrone.exe -nobrowser
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
  do_with_root mv sonarr.service /lib/systemd/system/sonarr.service

  echo -e '\nStarting service:  Sonarr' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Starting service:\e[0;92m  Sonarr \e[0m" &&
  do_with_root systemctl enable sonarr.service >> /var/log/rpi-config_install.log 2>&1 &&
  do_with_root systemctl start sonarr.service >> /var/log/rpi-config_install.log 2>&1 &&

  # Radarr:  program
  echo -e '\nDownloading and installing program:  Radarr' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Downloading and installing program:\e[0;92m  Radarr \e[0m" &&
  cd ~/Downloads
  do_with_root curl -L -O $( curl -s https://api.github.com/repos/Radarr/Radarr/releases | grep linux.tar.gz | grep browser_download_url | head -1 | cut -d \" -f 4 ) >> /var/log/rpi-config_install.log 2>&1 &&
  do_with_root tar -xzf Radarr.develop.*.linux.tar.gz --directory /opt/ >> /var/log/rpi-config_install.log 2>&1 &&
  do_with_root chown -Rh pi:pi /opt/Radarr >> /var/log/rpi-config_install.log 2>&1 &&

  # Radarr:  service
  echo -e '\nCreating service for:  Radarr' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Creating service for:\e[0;92m  Radarr \e[0m" &&
  cat > radarr.service << EOF
[Unit]
Description=Radarr Daemon
After=syslog.target network.target

[Service]
User=pi
Group=pi
Type=simple
ExecStart=/usr/bin/mono /opt/Radarr/Radarr.exe -nobrowser
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
  do_with_root mv radarr.service /lib/systemd/system/radarr.service

  echo -e '\nStarting service:  Radarr' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Starting service:\e[0;92m  Radarr \e[0m" &&
  do_with_root systemctl enable radarr.service >> /var/log/rpi-config_install.log 2>&1 &&
  do_with_root systemctl start radarr.service >> /var/log/rpi-config_install.log 2>&1 &&

  # Lidarr:  program
  echo -e '\nDownloading and installing program:  Lidarr' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Downloading and installing program:\e[0;92m  Lidarr \e[0m" &&
  cd ~/Downloads
  do_with_root wget https://github.com/lidarr/Lidarr/releases/download/v0.3.1.471/Lidarr.develop.0.3.1.471.linux.tar.gz >> /var/log/rpi-config_install.log 2>&1 &&
  do_with_root tar -xzf Lidarr.develop.*.linux.tar.gz --directory /opt/ >> /var/log/rpi-config_install.log 2>&1 &&
  do_with_root chown -Rh pi:pi /opt/Lidarr >> /var/log/rpi-config_install.log 2>&1 &&

  # Lidarr:  service
  echo -e '\nCreating service for:  Lidarr' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Creating service for:\e[0;92m  Lidarr \e[0m" &&
  cat > lidarr.service << EOF
[Unit]
Description=Lidarr Daemon
After=syslog.target network.target

[Service]
User=pi
Group=pi
Type=simple
ExecStart=/usr/bin/mono /opt/Lidarr/Lidarr.exe -nobrowser
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
  do_with_root mv lidarr.service /lib/systemd/system/lidarr.service
  echo -e '\nStarting service:  Lidarr' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Starting service:\e[0;92m  Lidarr \e[0m" &&
  do_with_root systemctl enable lidarr.service >> /var/log/rpi-config_install.log 2>&1 &&
  do_with_root systemctl start lidarr.service >> /var/log/rpi-config_install.log 2>&1

  # Ombi:  program
  cd ~
  echo -e '\nDownloading and installing program:  Ombi' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Adding package to sources.list for:\e[0;92m  Ombi \e[0m" &&
  echo "deb [arch=amd64,armhf] http://repo.ombi.turd.me/develop/ jessie main" | sudo tee "/etc/apt/sources.list.d/ombi.list" >> /var/log/rpi-config_install.log 2>&1 &&
  wget -qO - https://repo.ombi.turd.me/pubkey.txt | sudo apt-key add - >> /var/log/rpi-config_install.log 2>&1 &&
  echo -e "\e[0;96m> Package(s) Update Required \e[0m" &&
  sudo apt-get update >> /var/log/rpi-config_install.log 2>&1 &&
  echo -e "\e[0;96m> Downloading and installing program:\e[0;92m  Ombi \e[0m" &&
  sudo apt-get install ombi -y >> /var/log/rpi-config_install.log 2>&1 &&

  # Organizr:  program
  cd ~
  echo -e '\nDownloading and installing program:  Organizr' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Downloading and installing program:\e[0;92m  Organizr \e[0m" &&
  do_with_root git clone https://github.com/elmerfdz/OrganizrInstaller /opt/OrganizrInstaller >> /var/log/rpi-config_install.log 2>&1 &&
  cd /opt/OrganizrInstaller/ubuntu/oui >> /var/log/rpi-config_install.log 2>&1 &&
  do_with_root bash ou_installer.sh &&
  cd ~
}

do_torbox_maintenance_programs() {
  echo -e '\nDownload and Installation of maintenance utility programs\n'`date` >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;93m> Download and Installation of maintenance utility programs \e[0m\n" &&

  # Midnight Commander
  cd ~
  echo -e '\nDownloading and installing program:  Midnight Commander' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Downloading and installing program:\e[0;92m  Midnight Commander \e[0m" &&
  do_with_root apt-get install mc -y >> /var/log/rpi-config_install.log 2>&1 &&

  # Speedtest
  echo -e '\nDownloading and installing program:  Speedtest' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Downloading and installing program:\e[0;92m  Speedtest \e[0m" &&
  cd /usr/local/bin
  do_with_root apt-get install python-pip -y >> /var/log/rpi-config_install.log 2>&1 &&
  do_with_root easy_install speedtest-cli -y >> /var/log/rpi-config_install.log 2>&1
  cd ~

  # Cloud Commander
}

do_torbox_preassigned_settings() {
  whiptail --yesno "Have you met the following criteria before running the preassigned settings?\n
    • Rebooted after running the '1 First Time Boot'
    • Installed the '2 Requirement Packages'
    • Rebooted after installing all the '3 TorBox Programs'
    • All the services have been started by their respective port numbers
      via a local browser  (ie torboxIP:port - 192.168.0.60:8989)
      - Deluge  (torboxIP:8112)
      - Jackett (torboxIP:9117)
      - Sonarr  (torboxIP:8989)
      - Radarr  (torboxIP:7878)
      - Lidarr  (torboxIP:8686)
    " 20 80 6
    RET=$?
  if [ $? -eq 0 ]; then # yes

  echo -e '\nEditing, Download, Replacing, and Installation of preassgined settings\n'`date` >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;93m> Editing, Download, Replacing, and Installation of preassgined settings \e[0m\n" &&

  # Deluge
  echo -e '\nDownloading and replacing file(s) for:  Deluge' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Downloading and replacing file(s) for:\e[0;92m  Deluge \e[0m" &&
  do_with_root systemctl stop deluge && do_with_root systemctl stop deluge-web >> /var/log/rpi-config_install.log &&
  do_with_root wget https://github.com/D4rkSl4ve/RaspberryPi/raw/master/raspi-torbox/deluge/WebAPI-0.2.1-py2.7.egg -O /root/.config/deluge/plugins/WebAPI-0.2.1-py2.7.egg >> /var/log/rpi-config_install.log &&
  do_with_root chmod 666 /root/.config/deluge/plugins/WebAPI-0.2.1-py2.7.egg >> /var/log/rpi-config_install.log &&
  do_with_root rm /root/.config/deluge/core.conf >> /var/log/rpi-config_install.log &&
  do_with_root wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/deluge/core.conf -O /root/.config/deluge/core.conf >> /var/log/rpi-config_install.log &&
  do_with_root mv /usr/lib/python2.7/dist-packages/deluge/ui/web/js/deluge-all.js /usr/lib/python2.7/dist-packages/deluge/ui/web/js/deluge-all.js-backup >> /var/log/rpi-config_install.log &&
  do_with_root wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/deluge/deluge-all.js -O /usr/lib/python2.7/dist-packages/deluge/ui/web/js/deluge-all.js >> /var/log/rpi-config_install.log &&
  do_with_root chmod 644 /usr/lib/python2.7/dist-packages/deluge/ui/web/js/deluge-all.js >> /var/log/rpi-config_install.log &&
  do_with_root mv /usr/lib/python2.7/dist-packages/deluge/ui/web/auth.py /usr/lib/python2.7/dist-packages/deluge/ui/web/auth.py-backup >> /var/log/rpi-config_install.log &&
  do_with_root wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/deluge/auth.py -O /usr/lib/python2.7/dist-packages/deluge/ui/web/auth.py >> /var/log/rpi-config_install.log &&
  do_with_root chmod 644 /usr/lib/python2.7/dist-packages/deluge/ui/web/auth.py >> /var/log/rpi-config_install.log &&
  do_with_root systemctl start deluge && do_with_root systemctl start deluge-web >> /var/log/rpi-config_install.log

  # Jackett
  echo -e '\nDownloading and replacing file(s) for:  Jackett' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Downloading and replacing file(s) for:\e[0;92m  Jackett \e[0m" &&
  do_with_root systemctl stop jackett >> /var/log/rpi-config_install.log &&
  cd ~/.config/Jackett >> /var/log/rpi-config_install.log &&
  rm SeverConfig.json >> /var/log/rpi-config_install.log &&
  wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/jackett/ServerConfig.json -O ~/.config/Jackett/ServerConfig.json >> /var/log/rpi-config_install.log &&
  chmod 644 ~/.config/Jackett/ServerConfig.json >> /var/log/rpi-config_install.log &&
  do_with_root systemctl start jackett >> /var/log/rpi-config_install.log &&

  # Sonarr
  echo -e '\nDownloading and replacing file(s) for:  Sonarr' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Downloading and replacing file(s) for:\e[0;92m  Sonarr \e[0m" &&
  do_with_root systemctl stop sonarr >> /var/log/rpi-config_install.log &&
  cd ~/.config/NzbDrone >> /var/log/rpi-config_install.log &&
  rm config.xml && rm *.db* >> /var/log/rpi-config_install.log &&
  wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/sonarr/config.xml -O ~/.config/NzbDrone/config.xml >> /var/log/rpi-config_install.log &&
  chmod 644 ~/.config/NzbDrone/config.xml >> /var/log/rpi-config_install.log &&
  wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/sonarr/nzbdrone.db -O ~/.config/NzbDrone/nzbdrone.db >> /var/log/rpi-config_install.log &&
  chmod 644 ~/.config/NzbDrone/nzbdrone.db >> /var/log/rpi-config_install.log &&
  wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/sonarr/nzbdrone.db-journal -O ~/.config/NzbDrone/nzbdrone.db-journal >> /var/log/rpi-config_install.log &&
  chmod 644 ~/.config/NzbDrone/nzbdrone.db-journal >> /var/log/rpi-config_install.log &&
  do_with_root systemctl start sonarr >> /var/log/rpi-config_install.log &&

  # Radarr
  echo -e '\nDownloading and replacing file(s) for:  Radarr' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Downloading and replacing file(s) for:\e[0;92m  Radarr \e[0m" &&
  do_with_root systemctl stop radarr >> /var/log/rpi-config_install.log &&
  cd ~/.config/Radarr >> /var/log/rpi-config_install.log &&
  rm config.xml && rm *.db* >> /var/log/rpi-config_install.log &&
  wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/radarr/config.xml -O ~/.config/Radarr/config.xml >> /var/log/rpi-config_install.log &&
  chmod 644 ~/.config/Radarr/config.xml >> /var/log/rpi-config_install.log &&
  wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/radarr/nzbdrone.db -O ~/.config/Radarr/nzbdrone.db >> /var/log/rpi-config_install.log &&
  chmod 644 ~/.config/Radarr/nzbdrone.db >> /var/log/rpi-config_install.log &&
  wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/radarr/nzbdrone.db-journal -O ~/.config/Radarr/nzbdrone.db-journal >> /var/log/rpi-config_install.log &&
  chmod 644 ~/.config/Radarr/nzbdrone.db-journal >> /var/log/rpi-config_install.log &&
  do_with_root systemctl start radarr >> /var/log/rpi-config_install.log &&

  # lidarr
  echo -e '\nDownloading and replacing file(s) for:  Lidarr' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Downloading and replacing file(s) for:\e[0;92m  Lidarr \e[0m" &&
  do_with_root systemctl stop lidarr >> /var/log/rpi-config_install.log &&
  cd ~/.config/Lidarr >> /var/log/rpi-config_install.log &&
  rm config.xml && rm *.db* >> /var/log/rpi-config_install.log &&
  wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/lidarr/config.xml -O ~/.config/Lidarr/config.xml >> /var/log/rpi-config_install.log &&
  chmod 644 ~/.config/Lidarr/config.xml >> /var/log/rpi-config_install.log &&
  wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/lidarr/lidarr.db -O ~/.config/Lidarr/lidarr.db >> /var/log/rpi-config_install.log &&
  chmod 644 ~/.config/Lidarr/lidarr.db >> /var/log/rpi-config_install.log &&
  # wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/lidarr/lidarr.db-journal -O ~/.config/Lidarr/lidarr.db-journal >> /var/log/rpi-config_install.log &&
  # chmod 644 ~/.config/Lidarr/lidarr.db-journal >> /var/log/rpi-config_install.log &&
  do_with_root systemctl start lidarr >> /var/log/rpi-config_install.log &&

  ASK_TO_REBOOT=1
else
  return 0
fi
}

do_future_settings() {
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "This portion of the the script is not finished yet.\n" 20 60 2
  fi
}

# Command line options for non-interactive use

{ # Memory Split & Expand-Rootfs
for i in $*
do
  case $i in
  --memory-split)
    OPT_MEMORY_SPLIT=GET
    printf "Not currently supported\n"
    exit 1
    ;;
  --memory-split=*)
    OPT_MEMORY_SPLIT=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
    printf "Not currently supported\n"
    exit 1
    ;;
  --expand-rootfs)
    INTERACTIVE=False
    do_expand_rootfs
    printf "Please reboot\n"
    exit 0
    ;;
  --apply-os-config)
    INTERACTIVE=False
    do_apply_os_config
    exit $?
    ;;
  nonint)
    INTERACTIVE=False
    "$@"
    exit $?
    ;;
  *)
    # unknown option
    ;;
  esac
done
} #

#if [ "GET" = "${OPT_MEMORY_SPLIT:-}" ]; then
#  set -u # Fail on unset variables
#  get_current_memory_split
#  echo $CURRENT_MEMSPLIT
#  exit 0
#fi

{ # Everything else needs to be run as root
if [ -n "${OPT_MEMORY_SPLIT:-}" ]; then
  set -e # Fail when a command errors
  set_memory_split "${OPT_MEMORY_SPLIT}"
  exit 0
fi
} #

do_internationalisation_menu() {
  FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Localisation Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
    "I1 Change Locale" "Set up language and regional settings to match your location" \
    "I2 Change Timezone" "Set up timezone to match your location" \
    "I3 Change Keyboard Layout" "Set the keyboard layout to match your keyboard" \
    "I4 Change Wi-fi Country" "Set the legal channels used in your country" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    do_raspi_config_menu
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      I1\ *) do_change_locale ;;
      I2\ *) do_change_timezone ;;
      I3\ *) do_configure_keyboard ;;
      I4\ *) do_wifi_country ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
  do_raspi_config_menu
}

do_interface_menu() {
  FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Interfacing Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
    "P1 Camera" "Enable/Disable connection to the Raspberry Pi Camera" \
    "P2 SSH" "Enable/Disable remote command line access to your Pi using SSH" \
    "P3 VNC" "Enable/Disable graphical remote access to your Pi using RealVNC" \
    "P4 SPI" "Enable/Disable automatic loading of SPI kernel module" \
    "P5 I2C" "Enable/Disable automatic loading of I2C kernel module" \
    "P6 Serial" "Enable/Disable shell and kernel messages on the serial connection" \
    "P7 1-Wire" "Enable/Disable one-wire interface" \
    "P8 Remote GPIO" "Enable/Disable remote access to GPIO pins" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    do_raspi_config_menu
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      P1\ *) do_camera ;;
      P2\ *) do_ssh ;;
      P3\ *) do_vnc ;;
      P4\ *) do_spi ;;
      P5\ *) do_i2c ;;
      P6\ *) do_serial ;;
      P7\ *) do_onewire ;;
      P8\ *) do_rgpio ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
  do_raspi_config_menu
}

do_advanced_menu() {
  FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Advanced Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
    "A1 Expand Filesystem" "Ensures that all of the SD card storage is available to the OS" \
    "A2 Overscan" "You may need to configure overscan if black bars are present on display" \
    "A3 Memory Split" "Change the amount of memory made available to the GPU" \
    "A4 Audio" "Force audio out through HDMI or 3.5mm jack" \
    "A5 Resolution" "Set a specific screen resolution" \
    "A6 Pixel Doubling" "Enable/Disable 2x2 pixel mapping" \
    "A7 GL Driver" "Enable/Disable experimental desktop GL driver" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    do_raspi_config_menu
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      A1\ *) do_expand_rootfs ;;
      A2\ *) do_overscan ;;
      A3\ *) do_memory_split ;;
      A4\ *) do_audio ;;
      A5\ *) do_resolution ;;
      A6\ *) do_pixdub ;;
      A7\ *) do_gldriver ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
  do_raspi_config_menu
}

do_boot_menu() {
  if is_live ; then
    FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Boot Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
      "B1 Desktop / CLI" "Choose whether to boot into a desktop environment or the command line" \
      "B2 Wait for Network at Boot" "Choose whether to wait for network connection during boot" \
      3>&1 1>&2 2>&3)
  else
    FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Boot Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
      "B1 Desktop / CLI" "Choose whether to boot into a desktop environment or the command line" \
      "B2 Wait for Network at Boot" "Choose whether to wait for network connection during boot" \
      "B3 Splash Screen" "Choose graphical splash screen or text boot" \
      3>&1 1>&2 2>&3)
  fi
  RET=$?
  if [ $RET -eq 1 ]; then
    do_raspi_config_menu
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      B1\ *) do_boot_behaviour ;;
      B2\ *) do_boot_wait ;;
      B3\ *) do_boot_splash ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
  do_raspi_config_menu
}

do_network_menu() {
  FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Network Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
    "N1 Hostname" "Set the visible name for this Pi on a network" \
    "N2 Wi-fi" "Enter SSID and passphrase" \
    "N3 Network interface names" "Enable/Disable predictable network interface names" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    do_raspi_config_menu
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      N1\ *) do_hostname ;;
      N2\ *) do_wifi_ssid_passphrase ;;
      N3\ *) do_net_names ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
  do_raspi_config_menu
}

# RPi TorBox Interactive use loop

{ # Main Menu
if [ "$INTERACTIVE" = True ]; then
  [ -e $CONFIG ] || touch $CONFIG
  calc_wt_size
  while true; do
    if is_pi ; then
      FUN=$(whiptail --title "Raspberry Pi Torrent Box Configuration Menu (raspi-torbox)" --backtitle "$(cat /proc/device-tree/model)" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Finish --ok-button Select \
        "1 First Time Boot" "First Time Boot Changes Required (reboot required at end)" \
        "2 Requirement Packages" "Installation of required packages, create folders, and install log" \
        "3 TorBox Programs" "Installation of torrent box programs and services" \
        "4 Maintenance Utilities" "Installation of maintenance utilities" \
        "5 Preassigned Settings" "Installation of 'Programs' preassigned settings" \
        "6 Future" "Description" \
        "7 Update\Upgrade" "Repository Update and Upgade" \
        "8 Reboot RPi" "Reboot RPi to take effect" \
        "9 Raspi-Config Menu" "Raspberry Pi Configuration Menu" \
        3>&1 1>&2 2>&3)
    else
      FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Finish --ok-button Select \
        "1 Change User Password" "Change password for the current user" \
        "2 Network Options" "Configure network settings" \
        "3 Boot Options" "Configure options for start-up" \
        "4 Localisation Options" "Set up language and regional settings to match your location" \
        "5 SSH" "Enable/Disable remote command line access to your PC using SSH" \
        "6 Pixel Doubling" "Enable/Disable 2x2 pixel mapping" \
        "8 Update" "Update this tool to the latest version" \
        "9 About raspi-config" "Information about this configuration tool" \
        3>&1 1>&2 2>&3)
    fi
    RET=$?
    if [ $RET -eq 1 ]; then
      do_finish
    elif [ $RET -eq 0 ]; then
      if is_pi ; then
        case "$FUN" in
          1\ *) do_first_time_boot_menu ;;
          2\ *) do_torbox_requirement_packages ;;
          3\ *) do_torbox_directories && do_torbox_programs ;;
          4\ *) do_torbox_maintenance_programs ;;
          5\ *) do_torbox_preassigned_settings ;;
          6\ *) do_future_settings ;;
          7\ *) do_update && do_upgrade ;;
          8\ *) do_reboot ;;
          9\ *) do_raspi_config_menu ;;
          *) whiptail --msgbox "Programmer error: unrecognized option" 30 60 1 ;;
        esac || whiptail --msgbox "There was an error running option $FUN" 30 60 1
      else
        case "$FUN" in
          1\ *) do_change_pass ;;
          2\ *) do_network_menu ;;
          3\ *) do_boot_menu ;;
          4\ *) do_internationalisation_menu ;;
          5\ *) do_ssh ;;
          6\ *) do_pixdub ;;
          8\ *) do_update ;;
          9\ *) do_about ;;
          *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
        esac || whiptail --msgbox "There was an error running option $FUN" 30 60 1
      fi
    else
      do_exit
    fi
  done
fi
do_exit
} # End Main Menu
