;+
; NAME:
;    rgb2luma
;
; PURPOSE:
;    Convert an RGB image into a grayscale luminance image.
;
; CATEGORY:
;    Image processing
;
; CALLING SEQUENCE:
;    gray = rgb2luma(rgb)
;
; INPUTS:
;    rgb: array of RGB image data with dimensions [3, w, h], [w, 3, h] or
;         [w, h, 3].  
;
; KEYWORD FLAGS:
;    mean: Return the mean of the R, G, and B channels.
;    lightness: Return the mean of the maximum and minimum values in
;        the R, G and B channels.
;    hdtv: Use the HDTV standard for weighting R, G, and B channels.
;
;    Default: Use NTSC/PAL standard for calculating luminance.
;
; OUTPUTS:
;    gray: grayscale image with dimensions [w, h]
;
; MODIFICATION HISTORY:
; 06/08/2013 Written by David G. Grier, New York University
;
; Copyright (c) 2013 David G. Grier
;-

function rgb2luma, rgb, $
                   mean = mean, $
                   lightness = lightness, $
                   hdtv = hdtv

COMPILE_OPT IDL2

umsg = 'USAGE: gray = rgb2luma(rgb)'

if n_params() ne 1 then begin
   message, umsg, /inf
   return, 0
endif

if ~isa(rgb, /number, /array) then begin
   message, umsg, /inf
   message, 'RGB should be an array of RGB pixel values', /inf
   return, 0
endif

sz = size(rgb, /dimensions)
chroma = where(sz eq 3, isrgb)
if ~isrgb then begin
   message, umsg, /inf
   message, 'RGB is not a color image'
   return, 0
end

if keyword_set(mean) then $
   return, mean(rgb, dim = chroma+1)

if keyword_set(lightness) then begin
   max = max(rgb, min = min, dim = chroma+1)
   return, 0.5*(max + min)
endif

wgt = keyword_set(hdtv) ? [0.2126, 0.7152, 0.0722] : [0.299, 0.587, 0.114]

case chroma of
   0: return, reform(wgt[0]*rgb[0, *, *] + wgt[1]*rgb[1, *, *] + wgt[2]*rgb[2, *, *])
   1: return, reform(wgt[0]*rgb[*, 0, *] + wgt[1]*rgb[*, 1, *] + wgt[2]*rgb[*, 2, *])
   2: return, reform(wgt[0]*rgb[*, *, 0] + wgt[1]*rgb[*, *, 1] + wgt[2]*rgb[*, *, 2])
   else: begin
      message, umsg, /inf
      message, 'RGB is not an RGB image', /inf
      return, 0
   end
endcase

return, 0
end
