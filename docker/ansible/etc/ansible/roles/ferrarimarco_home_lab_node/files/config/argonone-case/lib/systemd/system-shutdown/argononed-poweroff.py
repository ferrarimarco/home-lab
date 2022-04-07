#!/usr/bin/python3

import sys

import RPi.GPIO as GPIO
import smbus

rev = GPIO.RPI_REVISION
if rev == 2 or rev == 3:
    bus = smbus.SMBus(1)
else:
    bus = smbus.SMBus(0)

if len(sys.argv) > 1:
    bus.write_byte(0x1A, 0)

    # powercut signal
    if sys.argv[1] == "poweroff" or sys.argv[1] == "halt":
        try:
            bus.write_byte(0x1A, 0xFF)
        except:
            rev = 0
