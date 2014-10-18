;+
; NAME:
;    VOB
;
; PURPOSE:
;    Object for extracting properly scaled grayscale video frames from VOB files
;
; CATEGORY:
;    Video processing
;
; CALLING SEQUENCE:
;    a = vob(filename)
;
; INPUTS:
;    filename: String containing name of VOB file.  May include
;        wildcard specifications
;
; SUBCLASSES:
;    DGGgrMPlayer
;    IDL_Object
;
; PROPERTIES:
;    filename: File name with wildcards expanded
;    framenumber: Current frame number
;    data: Image data for current image
;    dimensions: [w,h] dimensions of image
;
; METHODS:
;    VOB::Read
;        Reads next video frame into data buffer
;
;    VOB::Read()
;        Reads next video frame and returns the data.
;
;    VOB::Rewind
;        Closes and reopens video file at first frame.
;
;    GetProperty
;    SetProperty
;
; MODIFICATION HISTORY:
; 08/20/2013 Written by David G. Grier, New York University
; 12/06/2013 DGG and Bhaskar Jyoti Krishnatreya Change default
;    ROI from [4, dim[0]-13, 0, dim[1]-1] to 
;    [8, dim[0]-9, 0, dim[1]-1] for better compatibility with CCD cameras.
;
; Copyright (c) 2013 David G. Grier and Bhaskar Jyoti Krishnatreya
;-

;;;;;
;
; VOB::Rewind
;
pro vob::rewind

COMPILE_OPT IDL2, HIDDEN

self.DGGgrMPlayer::Rewind
self.read                       ; first frame is often bad
end

;;;;;
;
; VOB::Read()
;
function vob::read

COMPILE_OPT IDL2, HIDDEN

self.DGGgrMPlayer::Read
return, (*(self.data))[self.roi[0]:self.roi[1], self.roi[2]:self.roi[3]]
end

;;;;;
;
; VOB::GetProperty
;
pro vob::GetProperty, roi = roi, $
                      dimensions = dimensions, $
                      data = data, $
                      _ref_extra = ex

COMPILE_OPT IDL2, HIDDEN

if arg_present(dimensions) then $
   dimensions = [self.roi[1]-self.roi[0]+1, self.roi[3]-self.roi[2]+1]

if arg_present(roi) then roi = self.roi

if arg_present(data) then $
   data = (*(self.data))[self.roi[0]:self.roi[1], self.roi[2]:self.roi[3]]

self.DGGgrMPlayer::GetProperty, _strict_extra = ex

end

;;;;;
;
; VOB::Cleanup
;
pro vob::Cleanup

COMPILE_OPT IDL2, HIDDEN

self.DGGgrMPlayer::Cleanup

end

;;;;;
;
; VOB::Init()
;
function vob::Init, filename, $
                    roi = roi

COMPILE_OPT IDL2, HIDDEN

umsg = 'USAGE: a = vob(filename)'

if n_params() ne 1 then begin
   message, umsg, /inf
   return, 0
endif

fn = file_search(filename, count = nfiles)
if (nfiles ne 1) then begin
   message, umsg, /inf
   message, strtrim(nfiles, 2) + ' files matched the specification '+filename, /inf
   return, 0
endif

dim = [656, 480]

if ~self.DGGgrMPlayer::Init(fn, /gray, dim = dim) then $
   return, 0
self.read                       ; first frame often is bad

if isa(roi, /number) and (n_elements(roi) eq 4) then begin
   if (roi[0] ge roi[1]) or (roi[2] ge roi[3]) or $
      (roi[0] lt 0) or (roi[1] ge dim[1]) or $
      (roi[2] lt 0) or (roi[3] ge dim[2]) then begin
      message, umsg, /inf
      message, 'ROI: [x0, x1, y0, y1]', /inf
      self.cleanup
      return, 0
   endif
   self.roi = long(roi)
endif else $
   self.roi = [8, dim[0]-9, 0, dim[1]-1]

return, 1
end

;;;;;
;
; VOB_DEFINE
;
pro vob__define

COMPILE_OPT IDL2, HIDDEN

struct = {VOB, $
          inherits DGGgrMPlayer, $
          roi: [0L, 0, 0, 0] $
         }
end
