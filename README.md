# realmode-os
Writing a 16-bit real mode operating system in NASM

I'm going about this in a fairly traditional way by rolling my own floppy bootloader, reading in a stage 2 binary from a FAT formatted 3.5" 1.44MB floppy, then reading in the kernel proper.

# floppyloader
The floppy loader is a flat binary file that fits in the 512 byte boot sector of a floppy disk, it also contains the FAT descriptor. It's purpose is to read in the root directory and fat and load the stage2 into RAM and jump to it.

# stage2
The stage two loader exists to avoid the space constraints of the 512 byte boot sector, so that we can be more verbose in error messages and have more error checking while loading the actual kernel. Also provides support for a kernel binary greater than a full segment in size.

# kernel

