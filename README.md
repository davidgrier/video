# IDLvideo

**IDL routines for reading and processing video files on
UNIX-like operating systems**

IDL is the Interactive Data Language, and is a product of
[Exelis Visual Information Solutions](http://www.exelisvis.com)

IDLvideo is licensed under the GPLv3.

## What it does

IDLvideo uses the open-source MPlayer and MEncoder programs
to open and read video files.  Each frame of the video then
can be transferred into IDL as an array of bytes for further
processing

* **DGGgrMPlayer__define**: An IDL object that opens a video file,
decodes it, and extracts frames.

* **mplayer**: A simple resizable GUI movie player that demonstrates
the capabilities of the DGGgrMPlayer object.

* **mp_ripper**: An IDL procedure that uses the DGGgrMPlayer object
to rip a video file into individual frames that are stored on disk.

* **mp_normalize**: Remove overall intensity variations from a video file.

* **deinterlace**: Deinterlaces an image.