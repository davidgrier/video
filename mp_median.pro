;+
; NAME:
;    mp_median
;
; PURPOSE:
;    Calculate the pixel-by-pixel median of a byte-valued video
;
; CATEGORY:
;    Holographic microscopy, video analysis
;
; CALLING SEQUENCE:
;    med = mp_median(a)
;
; INPUTS:
;    a: video object of type DGGgrMPlayer.  Must be grayscale.
;
; KEYWORD PARAMETERS:
;    n0: first frame at which to start sampling
;    n1: last frame from which to sample
;
; OUTPUTS:
;    med: floating-point estimate for the median value at each pixel
;
; SIDE EFFECTS:
;    Reads through the movie, without rewinding.  Can be
;    time-consuming for long movies.
;
; RESTRICTIONS:
;    Assumes that each pixel in the image consists of 8 bits of
;    intensity data.  Other formats are not supported.
;
; PROCEDURE:
;    Estimate median value at each pixel by histogram analysis
;
; EXAMPLE:
; IDL> a = dgggrmplayer('VTS_03_1.VOB', /gray, dim = [656,480])
; IDL> bg = mp_median(a)
;
; MODIFICATION HISTORY:
; 01/15/2013 Written by David G. Grier, New York University
; 02/03/2013 DGG Minimum value is 1, rather than 0.
; 08/08/2013 DGG Recast as general-purpose video routine.
; 08/20/2013 DGG Update object syntax
;
; Copyright (c) 2013 David G. Grier
;-
function mp_median, a, n0 = n0, n1 = n1

COMPILE_OPT IDL2

umsg = 'med = mp_median(a, n0 = n0, n1 = n1)'

if ~isa(a, 'DGGgrMPlayer') then begin
   message, umsg, /inf
   message, 'A must be a DGGgrMPlayer object', /inf
   return, -1
endif

if ~a.greyscale then begin
   message, umsg, /inf
   message, 'A must be a grayscale video object', /inf
   return, -1
endif

if ~isa(n0, /number, /scalar) then $
   n0 = 0L

if isa(n1, /number, /scalar) then begin
   if n1 le n0 then begin
      message, 'n1 must be greater than n0', /inf
      return, -1
   endif
endif

if a.framenumber gt n0 then $
   a.rewind
while a.framenumber lt n0 do begin
   a.read
   if a.eof then begin
      message, umsg, /inf
      message, 'n0 exceeds the number of frames in the movie', /inf
      return, -1
   endif
endwhile

dim = a.dimensions
w = dim[0]
h = dim[1]
npts = w * h

b = fltarr(npts, 256) ; histogram
ndx = lindgen(npts)

nframes = 0.
if isa(n1, /number, /scalar) then begin
   while a.framenumber lt n1 and ~a.eof do begin
      b[ndx, a.read()]++
      nframes++
   endwhile
   if a.framenumber lt n1 then begin
      message, umsg, /inf
      message, 'n1 exceeds the number of frames in the movie', /inf
      return, -1
   endif
endif else begin
   while ~a.eof do begin
      b[ndx, a.read()]++
      nframes++
   endwhile
endelse 

b = total(b, 2, /cumulative) - nframes/2.
m = min(b, med, /absolute, dim = 2)
med = float(med)/npts > 1
return, reform(med, w, h)
end
