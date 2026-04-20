# colision_avoidance_Ardupilot
Colision Avoidance script for ardupilot drones (beta)
If you don like the way that the avoidaance of the ardupilot firmware works, try this!
Sometimes the ardupilot avoidance don work well with big automatic drones flying fast.
This is a simple script that uses a lidar sensor to detect obstacles and brake the drone.
This script changes the drone mode to BRAKE (17) when it detects an obstacle and then 
to RTL (6) after 10 seconds.

setup for the script:

1. setup the lidar sensor or radar (I use Lightware LW20/C) forward, in front of the drone
2. set RNGFND1_ORIENT to 0 (forward)
3. for my case (LW20/C):
    - set RNGFND1_TYPE to 1 (Serial)
    - set SERIAL4_PROTOCOL to 1 (Lidar)
    - set SERIAL4_BAUD to 115200
    - set RNGFND1_MAX_CM to 9500
4. set SCR_ENABLE to 1 to enable the script and save the script intro SD card in APM/scripts/ folder
5. reboot the drone
6. Set SCR_USER1 to the desired limit distance in cm
7. Set SCR_USER2 to the desired speed threshold in m/s

Remimber:
- This script is not tested in all conditions and may not work as expected.
- Use it at your own risk.
- I am not responsible for any damage or injury caused by the use of this script.
