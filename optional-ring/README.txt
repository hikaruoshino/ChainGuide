ChainGuide ring pack (optional)

These three files let ChainGuide draw rings and the skillchain name on the ground around the enemy, in the 3D world.
They are NOT used while they are in this folder (Windower's Lua only looks in libs/). To turn the rings on:

  1. Close the game (the daemon DLL stays loaded for the whole session).
  2. Move the three files from  ChainGuide/optional-ring/  into  ChainGuide/libs/
        worlddraw.dll   worlddraw_daemon.dll   worlddraw.lua
     (the libs/labels folder is already there)
  3. Start the game and load ChainGuide.   //cgd ring off  turns the rings off, //cgd ringtest on  shows a sample.

To go back: unload ChainGuide, close the game, move the three files back here.

What they are: ffxi_world_draw by Genoxd (https://github.com/genoxd/ffxi_world_draw, 0BSD license), built from source
commit 622e7c13e22d37cd9222f24cf5af01e86eeb333c with MinGW-w64 (GCC 16.2.0, UCRT). It hooks the game's Direct3D device and reads
the camera and the entity table from the game's memory, inside the game process. That is a bigger risk than a normal addon
(the FFXI Terms of Service, other overlays hooking the same device, crashes).

SHA256:
a66372c3a751a656f2e24a3fd06e3a6f11213c13dee629def7a2ea0ef884b0b9 *worlddraw.dll
9ba64e1cfb260f4e607380a98bf1d045eeaf38cbab299a58623fad910a8d8232 *worlddraw_daemon.dll
20c87378ce9fa1d51dab6d118b691807b1842fe7c5b966b22da7d978d0cc672d *worlddraw.lua

To build the files yourself instead of using these ones, download "ChainGuide-ring-source.zip" from the Releases page of this repository
(the library's source at the commit above, with the build steps).

License of the library: 0BSD (the text is in LICENSE-ffxi_world_draw-0BSD.txt in this folder).
