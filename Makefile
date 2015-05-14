ASM = nasm
ASMFLATFLAGS = -f bin
FLOPPYIMAGE = realos.img

all: floppyloader stage2

floppyloader: floppyloader.asm
	$(ASM) $(ASMFLATFLAGS) floppyloader.asm
    
stage2: stage2.asm
	$(ASM) $(ASMFLATFLAGS) stage2.asm

kernel: kernel.asm
	$(ASM) $(ASMFLATFLAGS) kernel.asm

installloader:
	dd if=floppyloader of=$(FLOPPYIMAGE) conv=notrunc

installstage2: stage2
	sudo mount -t msdos -o loop,uid=$$USER,gid=$$USER realos.img mnt/
	cp stage2 mnt/stage2.bin
	sudo umount mnt/

installkernel: kernel
	sudo mount -t msdos -o loop,uid=$$USER,gid=$$USER realos.img mnt/
	cp kernel mnt/kernel.bin
	sudo umount mnt/

mount:
	sudo mount -t msdos -o loop,uid=$$USER,gid=$$USER realos.img mnt/

umount: 
	sudo umount mnt/


