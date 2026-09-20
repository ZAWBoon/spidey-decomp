REMAKE TOOLS (M2) - planned
===========================
pkr_dump     : list + extract .PKR archives (format structs in ../../pkr.h:
               PKR_HEADER / PKR_DIRINFO / PKR_FILEINFO, zlib compression).
               Usage: pkr_dump <game.pkr> --list | --extract <dir> <out>
model_viewer : ImGui viewer - open extracted character, orbit camera,
               scrub animations. Daily workshop for M4/M5.
level_viewer : (later) view extracted level geometry + triggers.

All tools read from ../work/ (git-ignored). Never commit game files.
