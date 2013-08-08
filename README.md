# IDLvideo

**IDL routines for reading and processing video files on
UNIX-like operating systems**

IDL is the Interactive Data Language, and is a product of
[Exelis Visual Information Solutions](http://www.exelisvis.com).

IDLvideo is licensed under the GPLv3.

## What it does

The IDLvideo routines provide access to individual frames
from video files.  The DGGffVideoRead object class
makes use of the native support for reading video files
that was added in IDL 8.2.3.  DGGgrMPlayer uses the external
programs mplayer and mencoder to extract frames and pipe them
into IDL.  Although DGGffVideoRead is simpler and operates
on all platforms, it is limited by the ffmpeg libraries that
ship with IDL.  DGGgrMPlayer, by contrast, can read any video
format supported by mplayer, and thus is more functional.

* **DGGffVideoRead__define**: Extends the native IDL 
IDLffVideoRead object class to provide the functionality
of DGGgrMPlayer.

DGGgrMPlayer uses the open-source MPlayer and MEncoder programs
to open and read video files.  Each frame of the video then
can be transferred into IDL as an array of bytes for further
processing.  Because it relies on installed software rather
than libraries, IDLvideo does not have to be separately compiled,
and does not require any additions or modifications to IDL itself.

* **DGGgrMPlayer__define**: An IDL object that opens a video file,
decodes it, and extracts frames.

* **mplayer**: A simple resizable GUI movie player that demonstrates
the capabilities of the DGGgrMPlayer object.

* **mp_ripper**: An IDL procedure that uses the DGGgrMPlayer object
to rip a video file into individual frames that are stored on disk.

* **mp_normalize**: Remove overall intensity variations from a video file.

* **mp_median**: Computes running median of a video file.

The following utility routines are useful for working with
individual images taken from video streams.

* **deinterlace**: Deinterlaces an image.

* **rgb2luma**: Convert an RGB image to grayscale.

## Usage notes

IDL 8.2.X includes its own version of the FFmpeg libraries.
These may limit the functionality of DGGffVideoRead, and may
not be compatible with the installed versions of mplayer and mencoder
on which the DGGgrMPlayer object relies.  If this is a problem, follow
the published [instructions](http://www.exelisvis.com/docs/CreatingVideo.html)
on _Replacing the FFmpeg Version_.

DGGgrMPlayer relies internally on named pipes, which also are called fifos.
Fifos are available on UNIX-like systems, including MacOS, but not under
Windows.  Consequently, IDLVideo does not (yet) work on Windows systems.
DGGffVideoRead should be truly cross-platform compatible.
