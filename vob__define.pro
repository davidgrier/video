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
;
;-

;;;;;
;
; vob::_overloadPrint
;
function vob::_overloadPrint

COMPILE_OPT IDL2, HIDDEN

nl = string(10b)
str = string(self.filename,     format = '(%"filename   : \"%s\"\r")') + nl
str += string(self.framenumber, format = '(%"framenumber: %d")') + nl
str += string(self.geometry,    format = '(%"geometry   : [%d,%d]")') + nl
str += string(self.dimensions,  format = '(%"dimensions : [%d,%d]")') + nl
str += string(self.greyscale,   format = '(%"grayscale  : %d")') + nl
str += string(self.order,       format = '(%"order      : %d")')
return, str
end

;;;;;
;
; vob::_overloadHelp
;
function vob::_overloadHelp, varname

COMPILE_OPT IDL2, HIDDEN

nl = string(10b)
id = obj_valid(self, /get_heap_id)
sp = strjoin(replicate(' ', strlen(varname)+3))
fmt = '(%"dimensions  : [' + ((self.greyscale) ? '' : '3, ') + '%d, %d]")'

str = string(varname, self.filename, id, format = '(%"%s = VOB(\"%s\")\t<ObjHeapVar%d>")') + nl
str += sp + string(self.dimensions,  format = fmt) + nl
str += sp + string(self.framenumber, format = '(%"frame number: %d")')

return, str
end

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
   self.roi = [5, dim[0]-12, 0, dim[1]-1]

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
