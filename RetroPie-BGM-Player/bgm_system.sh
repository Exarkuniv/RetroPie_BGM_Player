#!/bin/bash 
#####################################################################
#Project		:	RetroPie_BGM_Player
#Version		:	1.0.0
#Git			:	https://github.com/Naprosnia/RetroPie_BGM_Player
#####################################################################
#Script Name	:	bgm_system.sh
#Date			:	20190216	(YYYYMMDD)
#Description	:	This script contain all functions needed by BGM.
#Usage			:	It should be called from other scripts using arguments.
#Author       	:	Luis Torres aka Naprosnia
#####################################################################
#Credits		:	crcerror : https://github.com/crcerror
#####################################################################

# Avoid multiple starts, so force close
[[ "$(pgrep -c -f $(basename $0))" -gt 1 ]] && exit

# read arguments and execute functions
function execute() {
	if [ "$#" -gt 0 ]; then

		case "$1" in
			-i)
				(bgm_init "$2") &
				;;
			-p)
				(bgm_play) &
				;;
			-s)
				(bgm_stop) &
				;;
			-setsetting)
				bgm_setsetting "$2" "$3"
				;;
			-r)
				bgm_restart
				;;
			-k)
				bgm_kill
				;;
			*)
				exit
				;;
		esac
	else
		exit
	fi
}

# shorten paths
RP=$HOME"/RetroPie"
RPMENU=$RP"/retropiemenu"
RPSETUP=$HOME"/RetroPie-Setup"
RPCONFIGS="/opt/retropie/configs/all"
BGM=$HOME"/RetroPie-BGM-Player"
BGMCONTROL=$BGM"/bgm_control"
BGMSETTINGS=$BGM"/bgm_settings.cfg"
BGMMUSICS=$RP"/roms/music"

# ALSA related vars
readonly CHANNEL="PCM"
readonly MUSICPLAYER="mpg123"
# get current volume
CHANNELVOLUME=$(amixer -M get $CHANNEL | grep -o "...%]")
CHANNELVOLUME=${CHANNELVOLUME//[^[:alnum:].]/}
# volume commands
VOLUMEZERO="amixer -q -M set $CHANNEL 0%"
VOLUMERESET="amixer -q -M set $CHANNEL $CHANNELVOLUME%"
FADEVOLUME=
VOLUMESTEP=

# settings area
# import settings file (or create one if not exist [with defaults])
if [ ! -e $BGMSETTINGS ]; then

	# set default settings and variables
	#bgm_volume=16384
	echo "bgm_volume=16384" >> $BGMSETTINGS
	#bgm_toggle=1
	echo "bgm_toggle=1" >> $BGMSETTINGS
	#bgm_fade=0
	echo "bgm_fade=0" >> $BGMSETTINGS
	#bgm_ingame=0
	echo "bgm_ingame=0" >> $BGMSETTINGS
	
fi
source $BGMSETTINGS >/dev/null 2>&1
# end of settings area

function bgm_init(){

	# if script called from autostart.sh, wait for omxplayer (splashscreen) to end
	if [ "$1" == "--autostart" ]; then
		while pgrep omxplayer >/dev/null; do sleep 1; done
		sleep 1
	fi
	
	(pgrep -x "mpg123" > /dev/null) && bgm_kill
	
	# start player (always)
	setsid $MUSICPLAYER -f $bgm_volume -Z $BGMMUSICS/*.mp3 >/dev/null 2>&1 &
	
	# check bgm_toggle, if 1 = play, else = stop
	if [ $bgm_toggle == 1 ]; then
	
		# check bgm_fade, if 1 apply fade, else leave it
		if [ $bgm_fade == 1 ]; then
			vol_fade_in
		fi
		
	else
	
		pkill -STOP $MUSICPLAYER
		
	fi
	
}

function bgm_play(){

	# check bgm_toggle, if 1 = play, else = null
	if [ "$bgm_toggle" -eq "1" ]; then
		# check bgm_ingame, if 0 = stop, else = null
		if [ "$bgm_ingame" -eq "0" ]; then
			# check bgm_fade, if 1 apply fade, else leave it
			if [ "$bgm_fade" -eq "1" ]; then
				vol_fade_in
			else
				pkill -CONT $MUSICPLAYER
			fi
		fi
	fi
	
}

function bgm_stop(){

	# check bgm_toggle, if 1 = stop, else = null
	if [ "$bgm_toggle" -eq "1" ]; then
		# check bgm_ingame, if 0 = stop, else = null
		if [ "$bgm_ingame" -eq "0" ]; then
			# check bgm_fade, if 1 apply fade, else leave it
			if [ "$bgm_fade" -eq "1" ]; then
				vol_fade_out
			else
				pkill -STOP $MUSICPLAYER
			fi
		fi
		
	fi
	
}

# fade related functions
function fade_set_step() {

	# reduce volume by steps | 100 -> 0 = slow -> fast
	case $FADEVOLUME in
		[1-4][0-9]|50) VOLUMESTEP=8 ;;
		[5-7][0-9]|80) VOLUMESTEP=5 ;;
		[8-9][0-9]|100) VOLUMESTEP=3 ;;
		*) VOLUMESTEP=5 ;;
	esac
	
}

function vol_fade_in(){

    $VOLUMEZERO
    sleep 0.2
    pkill -CONT $MUSICPLAYER
    FADEVOLUME=10
    until [[ $FADEVOLUME -ge $CHANNELVOLUME ]]; do
        fade_set_step
        FADEVOLUME=$(($FADEVOLUME+$VOLUMESTEP))
        amixer -q -M set "$CHANNEL" "${VOLUMESTEP}%+"
        sleep 0.2
    done
    $VOLUMERESET
}

function vol_fade_out(){
	FADEVOLUME=$CHANNELVOLUME
	until [[ $FADEVOLUME -le 10 ]]; do
        fade_set_step
        FADEVOLUME=$(($FADEVOLUME-$VOLUMESTEP))
        amixer -q -M set "$CHANNEL" "${VOLUMESTEP}%-"
        sleep 0.2
    done
    $VOLUMEZERO
    pkill -STOP $MUSICPLAYER
    sleep 0.2
    $VOLUMERESET
}
# end of fade related functions

# option menu related functions
function bgm_setsetting(){
	sed -i "s/^$1.*/$1=$2/g" $BGMSETTINGS
}
# end of option menu related functions

function bgm_kill(){

	killall $MUSICPLAYER >/dev/null 2>&1

}

function bgm_restart(){
	
	bgm_kill
	sleep 0.2
	bgm_init
}

execute "$@"