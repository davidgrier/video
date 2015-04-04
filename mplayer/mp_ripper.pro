;+
; NAME:
;    mp_ripper
;
; PURPOSE:
;    Rips a video file into individual image files, one for each frame.
;
; CATEGORY:
;    Video processing
;
; CALLING SEQUENCE:
;    mp_ripper, filename, prefix
;
; INPUTS:
;    filename: String containing name of video file to be ripped.
;
;    prefix: String containing name of directory into which frames
;        will be ripped.
;
; KEYWORD PARAMETERS:
;    format: String containing image format for individual frames.
;        Valid choices are
;        BMP, GIF, JPEG, PNG, PPM, SRF, TIFF and GDF.
;        Default: GDF
;
;    dimensions: [w,h] dimensions of frames [pixels]
;        Default: Natural size of video frames.
;
; KEYWORD FLAGS:
;    greyscale: If set, save images as greyscale.
;        Default: Save as RGB color.
;
;    order: If set, flip images vertically.
;
; RESTRICTIONS:
;    Only reads video formats that are understood by mplayer and
;    mencoder.
;
; PROCEDURE:
;    Uses DGGgrMPlayer object to read video file, and either
;    write_image or write_gdf to save images.
;
; MODIFICATION HISTORY:
; 07/06/2012 Written by David G. Grier, New York University
; 10/22/2012 Bhaskar Jyoti Krishnatreya and DGG: Fix code for other formats.
; 02/02/2013 BJK fixed code for other formats
; 02/02/2013 DGG Fix order test.
; 07/27/2013 DGG Update for new DGGgrMPlayer syntax.
;
; Copyright (c) 2012-2013 David G. Grier and Bhaskar Jyoti Krishnatreya
;-

pro mp_ripper, filename, prefix, $
               greyscale = greyscale, $
               dimensions = dimensions, $
               order = order, $
               format = format

COMPILE_OPT IDL2

; usage message
umsg = 'USAGE: mp_ripper, filename, prefix'

if n_params() ne 2 then begin
   message, umsg, /inf
   return
endif

; Create player object
if n_elements(order) ne 1 then order = 1 ; flip by default

player = dgggrmplayer(filename, $
                      greyscale = greyscale, dimensions = dimensions, order = order)

if ~isa(player, 'DGGgrMPlayer') then begin
   message, umsg, /inf
   message, 'could not open '+filename, /inf
   return
endif

if ~isa(prefix, 'string') then begin
   message, umsg, /inf
   message, 'prefix must be a string', /inf
   return
endif

; File format
formats = ['bmp', 'gif', 'png', 'ppm', 'jpeg', 'srf', 'tiff', 'gdf']
if isa(format, 'string') then begin
   if ~total(strmatch(formats, format, /fold_case)) then begin
      message, umsg, /inf
      message, 'recognized formats: '+strjoin(formats, ', ', /single), /inf
      return
   endif
endif else $
   format = 'gdf'
fmt = '("/",3I02,".'+format+'")'
dogdf = strmatch('gdf', format, /fold_case)

; Create directory hierarchy
dir = prefix+'/00/00'
file_mkdir, dir
if ~file_test(dir, /directory, /write) then begin
   message, umsg, /inf
   message, 'Could not create directory: '+dir, /inf
   message, 'Make sure you have write permission for the specified directory', /inf
   return
endif
lev3 = 0L
lev2 = 0L
lev1 = 0L
while ~player.eof do begin
   ; Write next frame into working directory
   fn = string(lev1, lev2, lev3, format = fmt)
   if dogdf then $
      write_gdf, player.read(), dir+fn  $
   else $
      write_image, dir+fn, format, player.read()

   ; Create new directory if necessary
   if (++lev3 gt 99) then begin
      lev3 =  0L
      if (++lev2 gt 99) then begin
         lev2 = 0L
         if (++lev1 gt 99) then begin
            message, 'too many files! Stopping!', /inf
            return
         endif
      endif
      dir = prefix+string(lev1, lev2, format = '("/",I02,"/",I02)')
      file_mkdir, dir
      if ~file_test(dir, /directory, /write) then begin
         message, 'could not create '+dir, /inf
         return
      endif
   endif
endwhile

end
