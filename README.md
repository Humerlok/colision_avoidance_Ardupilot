# colision_avoidance_Ardupilot
Colision Avoidance script for ardupilot drones

setup the lidar sensor (I use Lightware LW20/C) forward, in front of the drone
set RNGFND1_ORIENT to 0 (forward)

for my case (LW20/C):
set RNGFND1_TYPE to 1 (Serial)
set SERIAL4_PROTOCOL to 1 (Lidar)
set SERIAL4_BAUD to 115200
set RNGFND1_MAX_CM to 9500

set SCR_ENABLE to 1 to enable the script and save the script intro SD card in APM/scripts/ folder
reboot the drone
Set SCR_USER1 to the desired limit distance in cm
