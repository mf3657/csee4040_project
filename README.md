# csee4040_project

### Project Description:
The creation of a piano learning game, playable with a midi keyboard, piano files can be loaded as .mid files.

Game logic will be executed in C, at which point a custom linux kernal module will make ioctl calls down the avalon bus of the Alterra Cyclone V SOC to communicate with the on chip FPGA, programmed with System Verilog, for VGA display and sound generation/output.

#### Contributors:
-  Anita Bui-Martinez (adb2221)
-  Michael John Flynn (mf3657)
-  Robel Wondwossen (rw3043)
-  Zakiy Tywon Manigo (ztm2106)


to run everthing use:
    make             # builds everything
    make run_logger  # runs midi_logger
    make run         # defaults to run_logger

