;+
; NAME:
;    vmedian
;
; PURPOSE:
;    Computes running median of image data using a reasonably
;    fast and memory efficient hierarchical algorithm
;
; INHERITS:
;    IDL_Object
;
; SYNTAX:
;    a = vmedian()
;
; PROPERTIES:
; [IGS] ORDER: Number of orders in the hierarchy of median buffers.
;            Default: 0
;            Effective buffer size is 3^(order + 1).
;            Setting order restarts initialization.
;
; [I S] DATA: Image data for initializing median calculation
;            Resets median buffer when set.
;
; [IGS] DIMENSIONS: [nx, ny] dimensions of image buffer
;            Resets median buffer when set.
;
; [ GS] INITIALIZED: flag: 1 if the median buffer is fully initialized.
;            Setting initialized to 0 resets median buffer.
;
; METHODS:
;    vmedian::Add, data
;        Adds image data to median buffer.
;
;    vmedian::Get()
;        Computes and returns current median
;
; MODIFICATION HISTORY:
; 04/06/2014 Written by David G. Grier, New York University
; 04/04/2015 Adapted to general video analysis.
;
; Copyright (c) 2014-2015 David G. Grier
;-
;;;;;
;
; vmedian::Get()
;
function vmedian::Get

  COMPILE_OPT IDL2, HIDDEN

  return, median(*self.buffer, dim = 1)
end

;;;;;
;
; vmedian::Add
;
pro vmedian::Add, data

  COMPILE_OPT IDL2, HIDDEN

  if n_params() ne 1 then return

  if (~ptr_valid(self.buffer) && $
      isa(data, /number, /array) && $
      size(data, /n_dimensions) eq 2) then begin
     self.dimensions = size(data, /dimensions)
     self.buffer = ptr_new(bytarr([3, self.dimensions]))
     for i = 1, 2 do $
        (*self.buffer)[i, *, *] = data
     self.index = 0
  endif
  
  if isa(self.next, 'vmedian') then begin
     self.next.add, data
     if self.next.index eq 0 then $
        (*self.buffer)[self.index++, *, *] = self.next.get()      
  endif else if array_equal(size(data, /dimensions), self.dimensions) then $
     (*self.buffer)[self.index++, *, *] = data
  
  if self.index eq 3 then begin
     self.initialized = 1
     self.index = 0
  endif
end

;;;;;
;
; vmedian::SetProperty
;
pro vmedian::SetProperty, order = order, $
                          dimensions = dimensions, $
                          data = data, $
                          initialized = initialized

  COMPILE_OPT IDL2, HIDDEN

  if isa(order, /number, /scalar) then begin
     self.order = (long(order) > 0) < 10
     if self.order eq 0 then $
        self.next = obj_new() $
     else begin
        if isa(self.next, 'vmedian') then $
           self.next.order = self.order - 1 $
        else $
           self.next = vmedian(order = order - 1, dimensions = self.dimensions)
     endelse
     self.initialized = 0
  endif

  if isa(self.next, 'vmedian') then $
     self.next.setproperty, dimensions = dimensions, data = data, initialized = initialized
  
  if isa(dimensions, /number) then begin
     self.dimensions = long(dimensions)
     self.buffer = ptr_new(replicate(1B, [3, self.dimensions]))
     self.index = 1L
     self.initialized = 0
  endif

  if isa(data, /number, /array) then begin
     self.dimensions = size(data, /dimensions)
     self.buffer = ptr_new(bytarr([3, self.dimensions]))
     for i = 0, 2 do $
        (*self.buffer)[i, *, *] = data
     self.index = 1L
     self.initialized = 0
  endif

  if isa(initialized, /number, /scalar) then $
     self.initialized = keyword_set(initialized)
end

;;;;;
;
; vmedian::GetProperty
;
pro vmedian::GetProperty, index = index, $
                          order = order, $
                          dimensions = dimensions, $
                          buffer = buffer, $
                          initialized = initialized

  COMPILE_OPT IDL2, HIDDEN

  if arg_present(index) then $
     index = self.index

  if arg_present(order) then $
     order = self.order

  if arg_present(dimensions) then $
     dimensions = self.dimensions

  if arg_present(buffer) then $
     buffer = self.buffer
  
  if arg_present(initialized) then $
     initialized = self.initialized
end

;;;;;
;
; vmedian::Init()
;
function vmedian::Init, order = order, $
                        data = data, $
                        dimensions = dimensions

  COMPILE_OPT IDL2, HIDDEN

  if order gt 0 then begin
     self.order = order
     self.next = vmedian(order = self.order-1, data = data, dimensions = dimensions)
  endif
  
  if isa(dimensions, /number) && (n_elements(dimensions) eq 2) then begin
     self.dimensions = long(dimensions)
     self.buffer = ptr_new(replicate(1B, [3, self.dimensions]))
  endif
  
  if isa(data, /number, /array) and (size(data, /n_dimensions) eq 2) then begin
     self.dimensions = size(data, /dimensions)
     self.buffer = ptr_new(bytarr([3, self.dimensions]))
     for i = 0, 2 do $
        (*self.buffer)[i, *, *] = data
     self.index = 1
  endif

  self.initialized = 0

  return, 1B
end

;;;;;
;
; vmedian::Cleanup
;
pro vmedian::Cleanup

  COMPILE_OPT IDL2

  if isa(self.next, 'vmedian') then $
     obj_destroy, self.next
  ptr_free, self.buffer
end

;;;;;
;
; numedial__define
;
pro vmedian__define

  COMPILE_OPT IDL2

  struct = {vmedian, $
            inherits IDL_Object, $
            buffer: ptr_new(), $
            dimensions: [0L, 0], $
            index: 0L, $
            initialized: 0L, $
            order: 0L, $
            next: obj_new() $
           }
end
