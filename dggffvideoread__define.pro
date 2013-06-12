;+
; NAME:
;    DGGffVideoRead
;
; PURPOSE:
;    Access frames from video sources
;
; CATEGORY:
;    Video analysis
;
; CALLING SEQUENCE:
;    vid = DGGffVideoRead(filename)
;
; INPUTS:
;    filename: Name of video file
;
; INHERITS:
;    IDLffVideoRead
;    IDL_Object
;
; PROPERTIES:
;    R: Required
;    G: Get
;    S: Set
;
;    data        [ G ] The last image read from the video stream.
;    next        [ G ] The next image in the video stream.
;    framenumber [ G ] The current frame number in the stream.
;    geometry    [ G ] [width, height] -- dimensions of the frames stored in
;                      the video file
;    dimensions  [ GS] [width, height] -- optionally scaled dimensions
;                      of frames returned by the object.
;                      Default: identical to geometry
;    grayscale   [ GS] Flag: If set, return grayscale images.
;                      Default: return RGB images.
;    order       [ GS] Flag: If set, flip image vertically
;    eof         [ G ] Flag: Set when an attempt is made to read past
;                      the end of the video stream.
;
; METHODS:
;    GetNext(): Overloads IDLffVideoRead::GetNext()
;               Reads the next frame from the video stream, processes and returns
;               the data.
;    ReadNext : Compatibility routine for DGGgrMPlayer::ReadNext
;               Reads and processes the next frame from the video stream, but does
;               not return the data.
;
; RESTRICTIONS:
;    Can only access video files in formats supported by the FFmpeg
;    libraries installed in the IDL bin directory.
;
;    Seek() and Rewind methods currently render the framenumber property meaningless.
;
; MODIFICATION HISTORY:
; 06/10/2013 Written by David G. Grier, New York University.
;
; Copyright (c) 2013 David G. Grier
;-

;;;;;
;
; DGGffVideoRead::Rewind
;
pro DGGffVideoRead::Rewind

COMPILE_OPT IDL2, HIDDEN

self -> IDLffVideoRead::Seek, 0
self.framenumber = 0

end

;;;;;
;
; DGGffVideoRead::ReadFrame
;
pro DGGffVideoRead::ReadFrame

COMPILE_OPT IDL2, HIDDEN

void = self -> GetNext()

end

;;;;;
;
; DGGffVideoRead::GetNext()
;
; Overloads IDLffVideoRead::GetNext()
;
function DGGffVideoRead::GetNext

COMPILE_OPT IDL2, HIDDEN

catch, error
if (error ne 0L) then begin
   catch, /cancel
   if self.framenumber eq 0 then begin
      image = self -> IDLffVideoRead::GetNext(/video)
   endif else begin
      self.eof = 1
      return, 0
   endelse
endif

if self.eof then $
   return, *self.data

image = self -> IDLffVideoRead::GetNext(/video)
if n_elements(image) le 1 then begin
   self.eof = 1
   return, *self.data
endif

self.framenumber++

if self.grayscale then begin
   image = rgb2luma(temporary(image))
   if total(self.dimensions-self.geometry) ne 0 then $
      image = congrid(temporary(image), self.dimensions[0], self.dimensions[1], /interp)
   if self.order then $
      image = reverse(temporary(image), 2)
endif else begin
   if total(self.dimensions-self.geometry) ne 0 then $
      image = congrid(temporary(image), 3, self.dimensions[0], self.dimensions[1])
   if self.order then $
      image = reverse(temporary(image), 3)
endelse

self.data = ptr_new(image, /no_copy)

return, *self.data

end

;;;;;
;
; DGGffVideoRead::SetProperty
;
pro DGGffVideoRead::SetProperty, dimensions = dimensions, $
                                 grayscale = grayscale, $
                                 order = order

COMPILE_OPT IDL2, HIDDEN

if isa(dimensions, /number) && (n_elements(dimensions) eq 2) then $
   self.dimensions = long(dimensions)

if n_elements(grayscale) eq 1 then $
   self.grayscale = keyword_set(grayscale)

if n_elements(order) eq 1 then $
   self.order = keyword_set(order)

end

;;;;;
;
; DGGffVideoRead::GetProperty
;
pro DGGffVideoRead::GetProperty, data = data, $
                                 next = next, $
                                 geometry = geometry, $
                                 dimensions = dimensions, $
                                 grayscale = grayscale, $
                                 order = order, $
                                 framenumber = framenumber, $
                                 eof = eof

COMPILE_OPT IDL2, HIDDEN

if arg_present(data) then data = *self.data
if arg_present(geometry) then geometry = self.geometry
if arg_present(dimensions) then dimensions = self.dimensions
if arg_present(grayscale) then grayscale = self.grayscale
if arg_present(order) then order = self.order
if arg_present(framenumber) then framenumber = self.framenumber
if arg_present(eof) then eof = self.eof
if arg_present(next) then next = self -> getnext()

end

;;;;;
;
; DGGffVideoRead::Cleanup
;
pro DGGffVideoRead::Cleanup

COMPILE_OPT IDL2, HIDDEN

self -> IDLffVideoRead::Cleanup

end

;;;;;
;
; DGGffVideoRead::Init()
;
function DGGffVideoRead::Init, filename, $
                               dimensions = dimensions, $
                               grayscale = grayscale, $
                               order = order

COMPILE_OPT IDL2, HIDDEN

if (self -> IDLffVideoRead::Init(filename) ne 1) then $
   return, 0

s = self.getstreams()
w = where(s.type eq 1, nvideostreams)
if nvideostreams lt 1 then begin
   self -> IDLffVideoRead::Cleanup
   message, 'No video streams in '+filename, /inf
   return, 0
endif
ndx = w[0]
self.geometry = [s[ndx].width, s[ndx].height]

if isa(dimensions, /number) &&  (n_elements(dimensions) eq 2) then $
   self.dimensions = long(dimensions) $
else $
   self.dimensions = self.geometry

self.grayscale = keyword_set(grayscale)
self.order = keyword_set(order)

void = self -> GetNext()

return, 1

end

;;;;;
;
; DGGffVideoRead__define
;
pro DGGffVideoRead__define

COMPILE_OPT IDL2, HIDDEN

struct = {DGGffVideoRead, $
          inherits IDLffVideoRead, $
          inherits IDL_Object, $
          data:        ptr_new(),  $ ; image data
          geometry:    [0L, 0L],   $ ; intrinsic width and height
          dimensions:  [0L, 0L],   $ ; scaled width and height
          framenumber: 0L,         $ ; frame number
          grayscale:   0,          $ ; flag: convert to grayscale
          order:       0,          $ ; flag: vertical flip
          eof:         0           $ ; end of file
         }

end
