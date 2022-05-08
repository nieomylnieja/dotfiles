#!/bin/sh

# set key repeat rate [delay per/sec]
xset r rate 200 26

compton &
nitrogen --restore &
xautolock -time 5 -locker slock &
