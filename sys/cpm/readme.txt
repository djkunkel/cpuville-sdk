1. Start machine with a blank disk or one you want to overwrite
2. Load cpm22.cim at org_ccp address in locations.asm
3. Load cbios.cim at org_bios address in locations.asm
4. Load putsys.cim into 0800 and run to save CPM system memory image to disk
5. Load cpmloader.cim into 0800 and diskwr to location 0 on the disk
6. Load format.cim into 0800 and run to format the filesystem on the disk
7. Run monitor cpm and CPM should start
8. Reset to monitor and load savestub.cim to 0800
9. Load a max 1024 com file to 0900 (like pcget.com)
10. Run 0800 to launch cpm 
11. Use SAVE X FILE.COM (where X is number of 256 byte pages you want to save from step 9)


Notes:
CBIOS still assumes 64 SPT for the warm boot, so we should adjust however we are only using 50 sectors right now for the system