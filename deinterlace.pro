;+
; NAME:
;    deinterlace
;
; PURPOSE:
;    Deinterlaces an (interlaced) image.
;
; CATEGORY:
;    Image analysis
;
; CALLING SEQUENCE:
;    b = deinterlace(a)
;
; INPUTS:
;    a: [nx,ny] grayscale image or
;       [nx,ny,3] color image
;
; OPTIONAL INPUTS:
;    field: 0: do not deinterlace
;           even number: return even field
;           odd number: return odd field
;
; KEYWORD FLAG:
;    odd: if set, return image based on odd field.
;         Default: return even field
;    even: Return the even field.
;
; OUTPUTS:
;    b: [nx,ny] deinterlaced image or
;       [nx,ny,3] deinterlaced color image
;
; RESTRICTIONS:
;    Only works on gray-scale images.
;
; PROCEDURE:
;    Use IDL array subscripting to obtain the
;    even, or optionally odd, field from the array.
;
; NOTES:
;    Perhaps this can be done better using interpol?
;
; MODIFICATION HISTORY:
; 10/18/2008 David G. Grier, New York University.  Formalized an
;    informal utility that has been in use since the 1990's.
; 01/24/2009 DGG revised to use indexing rather than congrid,
;    thereby eliminating off-by-one errors when comparing
;    odd and even frames.
; 06/17/2012 DGG added EVEN keyword and usage message.
; 07/18/2012 DGG works for 3D images.
; 01/27/2013 DGG added optional FIELD input.  Reworked index math.
;
; Copyright (c) 2008-2013 David G. Grier
;-
function deinterlace, image, field,$
                      odd = odd, $
                      even = even

COMPILE_OPT IDL2

umsg = 'USAGE: result = deinterlace(image)'

if n_params() lt 1 then begin
   message, umsg, /inf
   return, -1
endif

if n_params() eq 2 then begin
   if round(field) eq 0 then $
      return, image
endif

if ~isa(image, /number, /array) then begin
   message, umsg, /inf
   message, 'IMAGE must be a numeric array'
   return, image
endif

sz = size(image)
if sz[0] ne 2 and sz[0] ne 3 then begin
   message, umsg, /inf
   message, 'IMAGE must be two- or three-dimensional', /inf
   return, image
endif

ny = sz[2]
nodd = ny / 2                   ; number of odd lines
neven = ny - nodd               ; number of even lines
noi = nodd - 1                  ; number of interpolated odd lines
nei = neven - 1                 ; number of interpolated even lines

a = float(image)

doodd = (n_params() eq 2) ? (round(field) mod 2) : $
        keyword_set(odd) and ~keyword_set(even)

if doodd then begin
   n1 = (neven - 1 < noi)
   ao = a[*, 1:*:2, *]
   aoi = (ao + ao[*, 1:*, *])/2.
   a[*, 2:2*n1:2, *] = aoi[*, 0:n1-1, *]
endif else begin
   n1 = (nodd < nei) - 1
   ae = a[*, 0:*:2, *]
   aei = (ae + ae[*, 1:*, *])/2.
   a[*, 1:2*n1:2, *] = aei[*, 0:n1-1, *]
endelse

return, a
end
