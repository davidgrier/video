;+
; NAME:
;    mp_normalize
;
; PURPOSE:
;    Correct flickering in greyscale movies by setting the
;    median value of each frame.
;
; CATEGORY:
;    Multimedia, Video analysis
;
; CALLING SEQUENCE:
;    mp_normalize, filename, [outname]
;
; INPUTS:
;    filename: String containing the name of the video to normalize
;
; OPTIONAL INPUTS:
;    outname: String containing the name of the normalized video
;        Default: Add "a.avi" to the basename of the input video
;        filename.  E.g. If filename is "myfile.mpg", the output
;        file will be "myfilea.avi".
;
; RESTRICTIONS:
;    Can only read those video formats that are understood by
;    DGGgrMPlayer, and can only write those video formats understood
;    by IDLffVideoWrite.  Currently, only AVI files are written.
;
; PROCEDURE:
;    Read each frame from the input video, scale to achieve the
;    median value of the first frame, and write to output file.
;
; MODIFICATION HISTORY:
; 07/13/2012 Written by David G. Grier, New York University
;
; Copyright (c) 2012 David G. Grier
;
;-

pro mp_normalize, filename, outname

COMPILE_OPT IDL2

umsg = 'USAGE: mp_normalize, filename, outname'

if n_params() eq 0 or n_params() gt 2 then begin
   message, umsg, /inf
   return
end

if n_params() eq 1 then $
   outname = basename(filename) + 'a.avi'

ivid = dgggrmplayer(filename, /greyscale, /order)
if ~isa(ivid, 'DGGgrMPlayer') then begin
   message, umsg, /inf
   message, 'could not open input video file: '+filename, /inf
   return
endif

ovid = idlffvideowrite(outname)
if ~isa(ovid, 'IDLffVideoWrite') then begin
   obj_destroy, ivid
   message, umsg, /inf
   message, 'could not open output video file: '+outname, /inf
   return
endif
dim = ivid.dimensions
w = dim[0]
h = dim[1]
stream = ovid.addvideostream(w, h, ivid.fps)

a = ivid.next
med = median(a)
while ~ivid.eof do begin
   a = ivid.data
   b = float(a) * med / median(a) < 255.
   b = rebin(reform(b, 1, w, h), 3, w, h)
   void = ovid.put(stream, byte(b))
   ivid.readframe
endwhile

ovid.cleanup
obj_destroy, ivid

end
