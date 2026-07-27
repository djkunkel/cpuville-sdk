#!/bin/bash
zmac -c --oo cim,lst cbios.asm
zmac --oo cim,lst cpmloader.asm
zmac --oo cim,lst format.asm
zmac -8 --oo cim,lst pcget.asm
zmac -8 --oo cim,lst pcput.asm
zmac -c --oo cim,lst putsys.asm
zmac -c --oo cim,lst cpm22.asm
zmac --oo cim,lst savestub.asm