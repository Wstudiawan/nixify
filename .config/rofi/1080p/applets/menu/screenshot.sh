#!/usr/bin/env bash

## Author  : Aditya Shakya
## Mail    : adi1090x@gmail.com
## Github  : @adi1090x
## Twitter : @adi1090x

style="$($HOME/.config/rofi/applets/menu/style.sh)"

dir="$HOME/.config/rofi/applets/menu/configs/$style"
rofi_command="rofi -theme $dir/screenshot.rasi"

# Error msg
msg() {
	rofi -theme "$HOME/.config/rofi/applets/styles/message.rasi" -e "Please install 'flameshot' first."
}

# Options
screen=""
area=""
window=""

# Variable passed to rofi
options="$screen\n$area\n$window"

chosen="$(echo -e "$options" | $rofi_command -p 'App : flameshot' -dmenu -selected-row 1)"
case $chosen in
    $screen)
		if [[ -f /usr/bin/flameshot ]]; then
			sleep 1;flameshot full -p ~/Pictures -c
		else
			msg
		fi
        ;;
    $area)
		if [[ -f /usr/bin/flameshot ]]; then
			flameshot -s 'Screenshot_%Y-%m-%d-%S_$wx$h.png' -e 'mv $f $$(xdg-user-dir PICTURES) ; viewnior $$(xdg-user-dir PICTURES)/$f'
		else
			msg
		fi
        ;;
    $window)
		if [[ -f /usr/bin/flameshot ]]; then
			sleep 1; flameshot -u 'Screenshot_%Y-%m-%d-%S_$wx$h.png' -e 'mv $f $$(xdg-user-dir PICTURES) ; viewnior $$(xdg-user-dir PICTURES)/$f'
		else
			msg
		fi
        ;;
esac

