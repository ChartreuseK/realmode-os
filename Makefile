ASM = nasm
ASMFLATFLAGS = -f bin
FLOPPYIMAGE = realos.img

all: floppyloader stage2

floppyloader: floppyloader.asm
	$(ASM) $(ASMFLATFLAGS) floppyloader.asm
    
stage2: stage2.asm
	$(ASM) $(ASMFLATFLAGS) stage2.asm


installloader:
	dd if=floppyloader of=$(FLOPPYIMAGE) conv=notrunc

mount:
	sudo mount -t msdos -o loop,uid=$$USER,gid=$$USER realos.img mnt/

umount: 
	sudo umount mnt/
