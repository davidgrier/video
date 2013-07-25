;+
; NAME:
;    DGGgrMPlayer
;
; PURPOSE:
;    Uses mplayer and mencoder to read frames from a video file.
;
; CATEGORY:
;    Object graphics, multimedia
;
; CALLING SEQUENCE:
;    a = DGGgrMPlayer([filename])
;
; SUPERCLASS:
;    IDL_Object: permits access to properties through dot notation.
;
; PROPERTIES:
;    I: set at initialization
;    G: get
;    S: set after initialization
;       NOTE: Setting properties restarts a video
;
; Properties likely to be of interest to most users:
;    filename    [IGS] String containing name of video file
;    data        [ G ] Array containing current video data
;    geometry    [ G ] two-element array (w,h) of intrinsic dimensions
;    dimensions  [IGS] two-element array (w,h) of desired dimensions
;    greyscale   [IGS] FLAG: if set, convert to greyscale
;    order       [IGS] FLAG: if set, flip image vertically
;    next        [ G ] Array containing data from the next video frame
;    framenumber [ G ] Current frame number
;    bitrate     [ G ] Intended bitrate
;    fps         [ G ] Intended playback rate [frames/s]
;    aspect      [ G ] Intended aspect ratio
;    length      [ G ] Length of video [s]
;    codec       [ G ] String describing the video's codec
;    eof         [ G ] FLAG: end-of-file
; 
; Properties identifying required external programs:
;    mplayer     [IG ] string containing name of mplayer executable
;    mencoder    [IG ] string containing name of mencoder executable
;    NOTE: By default, these programs are assumed to be in the path,
;    and usually do not need to be specified.
;
; Properties related to internal functioning:
;    pid         [ G ] process ID of mencoder
;    fifo        [ G ] name of fifo used for data transfer
;    lun         [ G ] logical unit number of open fifo
;
; METHODS
;    GetProperty
;    SetProperty
;
;    Read
;        Read the next video frame into the DATA property.
;        The frame data can be obtained with the GetProperty method.
;            Example:
;            IDL> player->Read
;            IDL> frame = player.data
;        Read is called implicitly when getting the NEXT
;        property.  The foregoing example is equivalent to
;            Example:
;            IDL> frame = player.next
;        Reading past the end of the video file sets the EOF property
;        and loads a blank image into DATA.  To avoid getting a blank
;        frame ...
;            Example:
;            IDL> player->Read
;            IDL> if ~player.eof then frame = player.data
;
;    Read()
;	Read the next video frame into the DATA property
;       and return the data.
;
;    Rewind
;        Start reading current video file from the beginning.
;            Example:
;            if player.eof then player->Rewind
;
; PROCEDURE:
;    Uses mplayer -identify to obtain information about the video file.
;    Uses mencoder to write video data frame-by-frame to a fifo, also
;    called a named pipe.  Reads video data from fifo using READU.
;
; REQUIREMENTS:
;    Working installation of mplayer and mencoder.
;    http://www.mplayerhq.hu/
;
; SIDE EFFECTS:
;    Uses SPAWN to execute commands.  Creates a named pipe as a
;    temporary file that is deleted when the object is cleaned up.
;
; RESTRICTIONS:
;    Tested on Unix-like systems (Ubuntu 12.04 and Mac OS X).
;    DGGgrMPlayer possibly can be made to work under cygwin.
;
; NOTES:
;    1. Can this be done with mplayer alone?  If so, then we don't
;       need mencoder.
;    2. Implement seeking?  This might permit videos to be treated
;       like arrays.
;    3. Windows implementation?  This might require an alternative
;       to named pipes, which apparently are handled differently
;       under Windows.
;
; EXAMPLES:
;    Example 1: Play a movie in a function-graphics window, first
;    casting it to greyscale, flipping it vertically and scaling its
;    dimensions:
;
;    player = DGGgrMPlayer("myvideofile.mpg", /order, /grey, $
;                          dimensions=[640,480])
;    img = image(player.next)
;    while ~player.eof do img.putdata, player.next
;
;    Example 2: Rewind the movie and play it again:
;
;    player.rewind
;    while ~player.eof do img.putdata, player.next
;
; MODIFICATION HISTORY:
; 05/07/2012 Written by David G. Grier, New York University
; 05/09/2012 DGG Simplify timestamp in fifo filename.  Documentation
;    upgrades.  Added GRAY as synonym for GREY.
; 05/10/2012 DGG Rename VIDEO property to FILENAME for clarity.
;    Experimental support for camera input under linux.
; 07/03/2012 DGG Revised properties to more closely resemble
;    IDLgrImage.
; 07/05/2012 DGG Renamed RATE property to FPS for compatibility with
;    IDLffVideoWriter.
; 09/17/2012 DGG Added GEOMETRY property.  Updated code for setting
;    dimensions.  Fixed keyword flags in SetProperty method.
; 09/24/2012 DGG Simplified DIMENSIONS code to accommodate Rewind
;    method.
; 01/15/2013 DGG Overloaded PRINT and HELP.
; 02/05/2013 DGG Changed grayscale mplayer option to -vf=y8,scale.
; 02/19/2013 DGG added Get method for ASPECT and BITRATE properties.
; 07/25/2013 DGG Renamed ReadFrame to Read.  Added Read() method.
;
; Copyright (c) 2012-2013 David G. Grier
;-
;;;;;
;
; DGGgrMPlayer::Read
;
; Read next frame from video stream
;
pro DGGgrMPlayer::Read

COMPILE_OPT IDL2, HIDDEN

catch, error
if (error ne 0L) then begin
   self.eof = 1
   catch, /cancel
   return
endif

if self.eof then return

readu, self.lun, *self.data
self.framenumber++

end

;;;;;
;
; DGGgrMPlayer::Read()
;
; Reads next video frame and returns the data
;
function DGGgrMPlayer::Read

COMPILE_OPT IDL2, HIDDEN

self->read
return, *self.data
end

;;;;;
;
; DGGgrMPlayer::VideoFormat
;
; Use mplayer to determine video format of source
; and populate internal variables with the result
;
function DGGgrMPlayer::VideoFormat

COMPILE_OPT IDL2, HIDDEN

; input from video camera
if self.video then begin
   if ~file_test(self.filename, /read) then begin
      message, 'cannot read ' + self.filename,  /inf
      return, 0
   endif
   self.geometry = [640L, 480]
   return, 1
end

; regular video file: make sure file exists and can be read
if ~file_test(self.filename, /read, /regular) then begin
   message, self.filename + ' is not a readable file', /inf
   return, 0
endif

; use mplayer to identify video format
flags = ' -really-quiet' + $     ; do not print startup messages
        ' -nolirc' + $           ; do not use remote control
        ' -vc null -vo null' + $ ; do not translate video
        ' -ao null' + $          ; do not translate audio
        ' -frames 0' + $         ; do not output any frames
        ' -identify '            ; report video format to stdout
spawn, self.mplayer + flags + self.filename, unit = lun, exit_status = status

a = ''
while ~eof(lun) do begin
   readf, lun, a
   b = strsplit(a, '=', /extract)
   case b[0] of
      'ID_VIDEO_FORMAT'  : self.codec = b[1]
      'ID_VIDEO_BITRATE' : self.bitrate = long(b[1])
      'ID_VIDEO_WIDTH'   : self.geometry[0] = fix(b[1])
      'ID_VIDEO_HEIGHT'  : self.geometry[1] = fix(b[1])
      'ID_VIDEO_FPS'     : self.fps = float(b[1])
      'ID_VIDEO_ASPECT'  : self.aspect = float(b[1])
      'ID_START_TIME'    : self.start = float(b[1])
      'ID_LENGTH'        : self.length = float(b[1])
      'ID_SEEKABLE'      : self.seekable = fix(b[1])
      else               :
   endcase
endwhile
close, lun
free_lun, lun

if strlen(self.codec) le 0 then begin
   message, self.filename + ' is not a recognized video file', /inf
   return, 0
endif

return, 1
end

;;;;;
;
; DGGgrMPlayer::OpenVideo
;
; Create fifo for video frames and attach mencoder to the fifo
;
function DGGgrMPlayer::OpenVideo, dimensions = dimensions

COMPILE_OPT IDL2, HIDDEN

self.eof = 1

if ~(self->VideoFormat()) then return, 0
if self.dimensions[0] eq 0 then $
   self.dimensions = self.geometry

;;; Create fifo
; time stamp for file name
fifoname = 'dgggrmplayer' + string(systime(1), format = '(F017.6)')
fifo = filepath(fifoname, /tmp) ; put fifo in directory for temporary files
spawn, 'mkfifo ' + fifo         ; make the fifo and make sure that it actually is created
if ~file_test(fifo, /read, /write, /named_pipe) then $
   return, 0
self.fifo = fifo

;;; Pipe output of mencoder through fifo:
;; Command line options for mencoder
; Basic mencoder settings ...
options = ' -really-quiet' + $     ; suppress startup messages
          ' -nosound' + $          ; discard audio track
          ' -ovc raw -of rawvideo' ; translate to raw video

; Video format ...
;     NOTE: to list available raw video formats:
;     $ mencoder -ovc raw -vf format=fmt=help
fmt = (self.greyscale) ? ' -vf format=y8,scale' : $ ; 8-bit grayscale [w, h]
      ' -vf format=rgb24'                           ; 24-bit RGB [3, w, h]
; optionally scale image dimensions ...
if ~array_equal(self.dimensions, self.geometry) then $
   fmt += string(self.dimensions, format = '(",scale=",I0,":",I0)')
; optionally flip frames vertically ...
if self.order then $
   fmt += ',flip'
options += fmt

; Output to fifo
options += ' -o ' + self.fifo

; Input from specified source
options += ' ' + self.filename
; ... including input from a video camera
if self.video then $
   options = ' tv:// -tv driver=v4l2 ' + options

; Run in background
options += ' &'

spawn, self.mencoder + options, pid = pid
self.pid = pid + 1
openr, lun, self.fifo, /get_lun, /delete
self.lun = lun

;;; Allocate memory for buffer
a = (self.greyscale) ? bytarr(self.dimensions) : $
    bytarr([3, self.dimensions])
self.data = ptr_new(a, /no_copy)

self.eof = 0
self.framenumber = 0

return, 1
end

;;;;;
;
; DGGgrMPlayer::CloseVideo
;
pro DGGgrMPlayer::CloseVideo

COMPILE_OPT IDL2, HIDDEN

; close connection to fifo
close, self.lun
free_lun, self.lun

; kill mencoder process if it is still running
if self.pid gt 0 then begin
   spawn, 'ps -o comm= -p ' + string(self.pid), res
   if strlen(res) gt 0 then $
      spawn, 'kill -9 ' + string(self.pid)           
   self.pid = 0L
endif
self.fifo = ''
self.eof = 1
end

;;;;;
;
; DGGgrMPlayer::Rewind
;
pro DGGgrMPlayer::Rewind

COMPILE_OPT IDL2, HIDDEN

self->CloseVideo
void = self->OpenVideo()

end

;;;;;
;
; DGGgrMPlayer::_overloadPrint
;
function DGGgrMPlayer::_overloadPrint

COMPILE_OPT IDL2, HIDDEN

str = string(self.filename, self.framenumber, self.geometry, $
             format = '(%"\"%s[%d]\": [%d,%d]")')
if ~array_equal(self.dimensions, self.geometry) then $
   str += string(self.dimensions, format = '(%"->[%d,%d]")')
str += self.greyscale ? ' Gray' : ' RGB'
str += self.order ? ' Flipped' : ''
return, str
end

;;;;;
;
; DGGgrMPlayer::_overloadHelp
;
function DGGgrMPlayer::_overloadHelp, varname

COMPILE_OPT IDL2, HIDDEN

return, string(varname, self._overloadPrint(), obj_valid(self, /get_heap_id), $
               format = '(%"%s = %s <ObjHeapVar%d (DGGgrMPlayer)>")')
end

;;;;;
;
; DGGgrMPlayer::GetProperty
;
pro DGGgrMPlayer::GetProperty, eof = eof,                 $
                               next = next,               $
                               framenumber = framenumber, $
                               filename = filename,       $
                               video = video,             $
                               mencoder = mencoder,       $
                               mplayer = mplayer,         $
                               pid = pid,                 $
                               fifo = fifo,               $
                               lun = lun,                 $
                               data = data,               $
                               geometry = geometry,       $
                               dimensions = dimensions,   $
                               greyscale = greyscale,     $
                               grayscale = grayscale,     $
                               order = order,             $
                               bitrate = bitrate,         $
                               fps = fps,                 $
                               aspect = aspect,           $
                               length = length,           $
                               codec = codec,             $
                               seekable = seekable

COMPILE_OPT IDL2, HIDDEN

if arg_present(eof) then begin 
   eof = self.eof
   return
endif

if arg_present(next) then begin
   self->Read
   next = *self.data
   return
endif

if arg_present(framenumber) then framenumber = self.framenumber
if arg_present(filename)    then filename = self.filename
if arg_present(video)       then video = self.video
if arg_present(mencoder)    then mencoder = self.mencoder
if arg_present(mplayer)     then mplayer = self.mplayer
if arg_present(pid)         then pid = self.pid
if arg_present(fifo)        then fifo = self.fifo
if arg_present(lun)         then lun = self.lun
if arg_present(data)        then data = *self.data
if arg_present(geometry)    then geometry = self.geometry
if arg_present(dimensions)  then dimensions = self.dimensions
if arg_present(greyscale)   then greyscale = self.greyscale
if arg_present(grayscale)   then grayscale = self.greyscale
if arg_present(order)       then order = self.order
if arg_present(bitrate)     then bitrate = self.bitrate
if arg_present(fps)         then fps = self.fps
if arg_present(aspect)      then aspect = self.aspect
if arg_present(length)      then length = self.length
if arg_present(codec)       then codec = self.codec
if arg_present(seekable)    then seekable = self.seekable

end

;;;;;
;
; DGGgrMPlayer::SetProperty
;
pro DGGgrMPlayer::SetProperty, filename = filename,     $
                               dimensions = dimensions, $
                               order = order,           $
                               greyscale = greyscale,   $
                               grayscale = grayscale

COMPILE_OPT IDL2, HIDDEN

if isa(filename, 'string') then $
   self.filename = filename

if n_elements(greyscale) eq 1 || n_elements(grayscale) eq 1 then $
   self.greyscale = keyword_set(greyscale) || keyword_set(grayscale)

if n_elements(order) eq 1 then $
   self.order = keyword_set(order)

if isa(dimensions, /number) && n_elements(dimensions) eq 2 then $
   self.dimensions = dimensions

if self.pid gt 0 then self->CloseVideo

self.eof = 1
self.framenumber = 0

if isa(self.filename, 'string') then $
   void = self->OpenVideo() $
else $
   self.data = ptr_new(0)

end

;;;;;
;
; DGGgrMPlayer::Cleanup
;
; Free resources
;
pro DGGgrMPlayer::Cleanup


COMPILE_OPT IDL2, HIDDEN

self->CloseVideo
ptr_free, self.data
end

;;;;;
;
; DGGgrMPlayer::Init
;
function DGGgrMPlayer::Init, filename,                $
                             mplayer = mplayer,       $
                             mencoder = mencoder,     $
                             dimensions = dimensions, $
                             order = order,           $
                             greyscale = greyscale,   $
                             grayscale = grayscale,   $
                             video = video
                             
COMPILE_OPT IDL2, HIDDEN

; check that underlying executables are available.
if isa(mplayer, 'string') then $
   self.mplayer = mplayer $
else $
   self.mplayer = 'mplayer'

spawn, 'which ' + self.mplayer, unit = lun
if eof(lun) then begin
   message, 'mplayer executable not found', /inf
   return, 0
endif

if isa(mencoder, 'string') then $
   self.mencoder = mencoder $
else $
   self.mencoder = 'mencoder'

spawn, 'which ' + self.mencoder, unit = lun
if eof(lun) then begin
   message, 'mencoder executable not found', /inf
   return, 0
endif

self.framenumber = 0
self.eof = 1

if isa(dimensions, /number) && n_elements(dimensions) eq 2 then $
   self.dimensions = dimensions
self.order = keyword_set(order)
self.greyscale = keyword_set(greyscale) || keyword_set(grayscale)
self.video = keyword_set(video)

; make sure that the video is valid
if isa(filename, 'string') then begin
   self.filename = filename
   if ~self->OpenVideo() then return, 0
endif else $
   self.data = ptr_new(0)

return, 1
end

;;;;;
;
; DGGgrMPlayer__define
;
; Define an object that extracts frames from a video file
;
pro DGGgrMPlayer__define

COMPILE_OPT IDL2, HIDDEN

struct = {DGGgrMPlayer, $
          inherits IDL_Object,     $ ; implicit get/set methods
          filename:    '',         $ ; name of video file
          mplayer:     'mplayer',  $ ; name of mplayer executable
          mencoder:    'mencoder', $ ; name of mencoder executable
          pid:         0L,         $ ; process ID of running mplayer instance
          fifo:        '',         $ ; name of fifo for transferring frames
          lun:         0L,         $ ; logical unit number used to read fifo
          data:        ptr_new(),  $ ; video frame
          geometry:    [0L, 0L],   $ ; intrinsic width and height
          dimensions:  [0L, 0L],   $ ; scaled width and height
          greyscale:   0,          $ ; flag: convert to grayscale
          order:       0,          $ ; vertical flip if set
          codec:       '',         $ ; video format
          bitrate:     0L,         $ ; bits per second
          fps:         0.,         $ ; frames per second
          aspect:      0.,         $ ; aspect ratio
          start:       0.,         $ ; starting time
          length:      0.,         $ ; length [sec]
          seekable:    0,          $ ; flag: set if video is seekable
          video:       0,          $ ; flag: if set then input is a video camera
          framenumber: 0L,         $ ; frame number
          eof:         0           $ ; end of file flag
         }

end
