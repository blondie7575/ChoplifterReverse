# Choplifter Reverse-Engineer

This is a full reverse engineer of the Apple II game Choplifter, written by Dan Gorlin in 1982. It was done clean-room style beginning only with the binary. I had no additional information about this game other than the disk image.

The source code here is fully documented and will build and run to a version of Choplifter that is binary-identical to the original, except for Dan Gorlin's custom floppy loader. In order to modernize this a bit, I wrote a new loader for it based on ProDOS, and this version boots Choplifter from ProDOS instead. Otherwise, it is identical.

For a full writeup about this reverse-engineer and how it was done (along with lots more information about this source code), see my blog post here:

[https://blondihacks.com/?p=9505](https://blondihacks.com/?p=9505)

A quick note on building this– the makefile ends by executing an AppleScript to launch Virtual II and boot the disk image. This is all obviously very Mac-specific and probably somewhat dependent on my local environment. If the build gets to the end and fails on the AppleScript (V2Make.Scpt) don't worry, the build completed and your disk image is good. You can remove the "emulate" target from the makefile if you're building on another platform, or if the AppleScript doesn't work for you.

This reverse engineer was complete by me, Quinn Dunki, on May 12, 2024, but this is of course still Dan's game and it is a brilliant piece of work. Reverse engineering it only *increased* my admiration of it. I doubt anyone would say that about most of what I've written in my career. 😁

Thanks Dan, for writing one of the best games on the platform, and I hope you don't mind that I did this to it.

