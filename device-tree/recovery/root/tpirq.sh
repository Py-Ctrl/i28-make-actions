#!/sbin/sh
# XTC i28: enable the cyttsp5 touch IRQ after TWRP has opened the input devices.
# Mirrors Android /init.common.rc: write "nobark" -> enable_cyttsp5_and_irq().
sleep 15
echo nobark > /sys/kernel/bbk_softdog/bbkwatchdog
exit 0
