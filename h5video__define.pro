;+
; NAME:
;    h5video
;
; PURPOSE:
;    Object class for recording and retrieving video data and
;    associated metadata in an HDF5 archive.  By default, images
;    are stored in an HDF5 group called "images".  Each image
;    is labeled with its floating-point timestamp, and optionally
;    may have metadata associated with it.  Additional groups
;    of images may be added.  Each group is annotated with
;    its timestamp and, optionally, with additional metadata.
;
; CATEGORY:
;    Image processing, video microscopy
;
; SYNTAX:
;    vid = h5video([filename])
;
; SUPERCLASSES:
;    IDL_Object
;
; PROPERTIES:
;        I: Can be set at initialization
;        G: Can be retrieved with GetProperty
;        S: Can be changed with SetProperty
;    FILENAME:
;        [IG ] Name of the HDF5 file.  Default: h5video.h5
;    GROUP:
;        [ GS] Name of currently active group.  Default: images
;    METADATA:
;        [IGS] Structure containing metadata for the current
;        group.  Default: !NULL
;    FILE_METADATA:
;        [IGS] Structure containing metadata for the file.
;        Default: !NULL
;    INDEX:
;        [IGS] Number of currently active image within currently
;        active group.  Reset to zero when GROUP changes.
;    STEPSIZE:
;        [IGS] Number of images by which INDEX advances between
;        calls to Read().  Default: 1
;    NIMAGES:
;        [ G ] Number of images in the active group.
;    NAMES:
;        [ G ] Array of strings containing the names of the
;        images in the currently active group.
;    READONLY:
;        [IG ] Flag.  If set, file has been opened read-only.
;        No new data can be added to it.
;
; INITIALIZATION KEYWORD FLAGS:
;    WRITE: If set, open a pre-existing file for writing.
;        Default is to open a new file for writing,
;        and to reopen a previously created file read-only.
;        This flag overrules that behavior and allows new
;        data to be appended to an archive.
;    OVERWRITE: If set, erase any file with FILENAME and
;        create a new archive.
;
; METHODS:
;    h5video::GetProperty
;    h5video::SetProperty
;        GetProperty and SetProperty may be performed for
;        individual properties using IDL_Object dot notation.
;
;    h5video::Read([name|index])
;        Returns one image from the current group.
;        OPTIONAL ARGUMENTS:
;            NAME: Name of the image to retrieve.
;            INDEX: Number of the image to retrieve.
;        If no argument is given, returns currently
;        active image in currently active group.
;
;    h5video::Metadata([index])
;        Returns metadata for the image numbered INDEX
;        OPTIONAL ARGUMENT:
;            INDEX: integer index of image.
;        If no argument is given, return metadata from
;        currently active image in currently active group.
;
;    h5video::Time([index])
;        Returns double-precision timestamp for the image
;        numbered INDEX.
;        OPTIONAL ARGUMENT:
;            INDEX: integer index of image.
;        If no argument is given, return timestamp from
;        currently active image in currently active group.
;
;    h5video::Name([index])
;        Returns name of image numbered INDEX.
;        OPTIONAL ARGUMENT:
;            INDEX: integer index of image
;        If no argument is given, return name of currently
;        active image in currently active group.
;
;    h5video::Write, image[, name]
;        Write one image to currently active group
;        ARGUMENT:
;            IMAGE: image data to store into active group.
;        OPTIONAL ARGUMENT:
;            NAME: name by which image will be stored.
;                Default: string containing timestamp.
;        KEYWORD ARGUMENT:
;            METADATA: Structure containing metadata for
;                this image.
;        NOTE: Raises an error if the archive is opened
;            read-only.
;
;    h5video::Transcode
;        Save image data in standard video format.
;
;    h5video::Close
;        Close the archive and destroy the object
;
; OVERLOADED OPERATORS:
;    video = h5video(...)
;    ARRAY INDEXING:
;        images = video[2:4] ; returns images 2, 3 and 4 from current group
;
;    FOREACH:
;        foreach image, video do tvscl, image
;
; NOTES:
; * Implement increment and decrement operators: change currently
;    active index
;
; MODIFICATION HISTORY:
; 02/11/2015 Written by David G. Grier, New York University
; 02/12/2015 DGG Implemented transcode method.  Enhanced timestamps.
;     File and each group is stamped with date of creation.
; 02/14/2015 DGG Initialization metadata is written to the file.
;     The METADATA property refers to the active group.
;
; Copyright (c) 2015 David G. Grier
;-
;;;;;
;
; h5video::Transcode
;
; Transcode images from active group to standard video format
;
pro h5video::Transcode

  COMPILE_OPT IDL2, HIDDEN

  fn = file_basename(self.filename, '.h5')
  if (self.group ne 'images') then $
     fn += '_' + self.group
  fn += '.mp4'
  video = IDLffVideoWrite(fn)
  
  image = self.read()
  sz = image.dim

  case image.ndim of
     2: begin
        image = bytarr(3, sz[0], sz[1], /nozero)
        sid = video.addvideostream(sz[0], sz[1], 30)
        foreach im, self do begin
           image[0, *, *] = im
           image[1, *, *] = im
           image[2, *, *] = im
           time = video.put(sid, image)
        endforeach
        end
     3: begin
        sid = video.addstream(sz[1], sz[2], 30)
        foreach image, self do $
           time = video.put(sid, image)
        end
     else: message, 'image data must be two- or three-dimensional', /inf
  endcase
  obj_destroy, video
end

;;;;;
;
; h5video::_overloadForeach
;
; Iterates over the images from the currently active group
;
function h5video::_overloadForeach, value, index

  COMPILE_OPT IDL2, HIDDEN

  nmax = h5g_get_num_objs(self.gid)
  index = isa(index) ? index+1L : 0L
  if index ge nmax then $
     return, 0

  value = self.read(index)
  return, 1
end

;;;;;
;
; h5video::_overloadBracketsRightSide
;
; Returns slices of the image pool from the currently
; selected group
;
function h5video::_overloadBracketsRightSide, isrange, $
   s1, s2, s3, s4, s5, s6, s7, s8

  COMPILE_OPT IDL2, HIDDEN

  on_error, 2
  
  if (n_params() ne 2) then $
     message, 'only one index is allowed'

  if ~isrange[0] then $
     return, self.read(s1) $
  else begin
     nmax = h5g_get_num_objs(self.gid)
     n0 = s1[0]
     n1 = s1[1]
     dn = s1[2]
     if (n0 lt -nmax) || (n1 lt -nmax) || (n0 ge nmax) || (n1 ge nmax) then $
        message, 'Illegal subscript range'
     if (n0 lt 0) then $
        n0 += nmax
     if (n1 lt 0) then $
        n1 += nmax
     if (n0 gt n1) &&  (dn gt 0) then $
        message, 'Illegal subscript range'
     ndx = [n0:n1:dn]
     res = list()
     foreach n, ndx do $
        res.add, self.read(n)
     return, res.toarray()
  endelse
     
  return, 0
end

;;;;;
;
; h5video::_overloadBracketsLeftSide
;
pro h5video::_overloadBracketsLeftSide, objref, value, $
                                        isrange, $
                                        s1, s2, s3, s4, s5, s6, s7, s8

  COMPILE_OPT IDL2, HIDDEN

  on_error, 2
  message, 'Cannot assign values to previously recorded video frames'
end

;;;;;
;
; h5video::CheckIndex()
;
; Private method to check whether a provided index is
; in the valid range for the active group.
;
function h5video::CheckIndex, ndx

  COMPILE_OPT IDL2, HIDDEN

  nimages = h5g_get_num_objs(self.gid)
  n = long(ndx)
  if (n lt -nimages) || (n ge nimages) then begin
     message, 'Attempt to subscript ' + $
              self.group + $
              ' with ' + $
              strtrim(n, 2) + $
              ' is out of range.', /inf
     n = -1L
  endif else if n lt 0 then $
     n += nimages
  return, n
end

;;;;;
;
; h5video::timestamp
;
pro h5video::timestamp, loc_id, str

  COMPILE_OPT IDL2, HIDDEN

  ts = 'Created on ' + systime(0)
  
  tid = h5t_idl_create(ts)
  sid = h5s_create_simple(1)
  aid = h5a_create(loc_id, 'timestamp', tid, sid)
  h5a_write, aid, ts
  h5a_close, aid
  h5s_close, sid
  h5t_close, tid
end

;;;;;
;
; h5video::timestamp()
;
function h5video::timestamp

  COMPILE_OPT IDL2, HIDDEN

  return, string(systime(/seconds), format = '(F017.6)')  
end

;;;;;
;
; h5video::Read()
;
; SYNTAX
; image = h5video::Read([name|index])
;
function h5video::Read, id

  COMPILE_OPT IDL2, HIDDEN

  on_error, 2

  if ~isa(id) then begin        ; read next frame in file (up to end)
     name = h5g_get_obj_name_by_idx(self.gid, self.ndx)
     self.ndx = (self.ndx + self.step) < (h5g_get_num_objs(self.gid) - 1UL)
  endif else if isa(id, /number, /scalar) then begin
     n = self.checkindex(id)
     if (n ge 0) then begin
        name = h5g_get_obj_name_by_idx(self.gid, n)
        self.ndx = n
     endif else $
        message, 'USAGE: h5video::Read([image_name|image_number])'
  endif else if isa(id, "string") then $
     name = id $
  else $
     message, 'USAGE: h5video::Read([image_name|image_number])'
  
  did = h5d_open(self.gid, name)
  image = h5d_read(did)
  h5d_close, did
  
  return, image
end

;;;;;
;
; h5video::Metadata()
;
function h5video::Metadata, ndx

  COMPILE_OPT IDL2, HIDDEN

  on_error, 2

  if ~isa(ndx) then $
     ndx = self.ndx
  if isa(ndx, /number, /scalar) then begin
     n = self.checkindex(ndx)
     if (n ge 0L) then begin
        did = h5d_open(self.gid, h5g_get_obj_name_by_idx(self.gid, n))
        aid = self.h5a_open_name(did, 'metadata')
        if (aid gt 0L) then begin
           return, h5a_read(aid)
           h5a_close, aid
        endif
        h5d_close, did
     endif
  endif

  return, !NULL
end

;;;;;
;
; h5video::Time()
;
function h5video::Time, ndx

  COMPILE_OPT IDL2, HIDDEN

  on_error, 2

  if ~isa(ndx) then $
     ndx = self.ndx
  if isa(ndx, /number, /scalar) then begin
     n = self.checkindex(ndx)
     if (n ge 0L) then begin
        self.ndx = n
        return, double(h5g_get_obj_name_by_idx(self.gid, n))
     endif
  endif

  message, 'USAGE: h5video::Time(ndx)'
  return, 0L
end

;;;;;
;
; h5video::Write
;
; SYNTAX
; h5video::Write, image, [name]
;
; Input:
; image: data to store in the active group
;
; Optional Input:
; name: string containing name of image.
;     Default: string containing timestamp
;
pro h5video::Write, image, name, $
                    metadata = metadata

  COMPILE_OPT IDL2, HIDDEN

  catch, error                  ; catch errors associated with writing data
  if (error ne 0L) then begin
     catch, /cancel
     message, !ERROR_STATE.MSG, /inf
     if did gt 0L then $
        h5d_close, did
     return
  endif

  if self.readonly then begin
     message, self.filename + ' opened read-only', /inf
     return
  endif
  
  if ~self.tid then begin
     self.tid = h5t_idl_create(image)        ; data type
;     self.sid = h5s_create_simple(image.dim) ; data space ; IDL 8.4
     self.sid = h5s_create_simple(size(image, /dimensions)) ; data space
  endif

;; FIXME check dimensions and type
  
  name = isa(name, 'string') ? name : self.timestamp()
  did = h5d_create(self.gid, name, self.tid, self.sid, gzip = 7)
  h5d_write, did, image
  if isa(metadata) then begin
     tid = h5t_idl_create(metadata)
     sid = h5s_create_simple(1)
     aid = h5a_create(did, 'metadata', tid, sid)
     h5a_write, aid, metadata
     h5a_close, aid
     h5s_close, sid
     h5t_close, tid
  endif
  h5d_close, did
end

;;;;;
;
; h5video::H5A_OPEN_NAME()
;
function h5video::H5A_OPEN_NAME, loc_id, name

  COMPILE_OPT IDL2, HIDDEN

  catch, error
  if (error ne 0L) then begin
     catch, /cancel
     return, 0L
  endif

  return, h5a_open_name(loc_id, name)
end

;;;;;
;
; h5video::H5G_OPEN()
;
; Open named group within specified location, if it exists,
; and return the group ID.
; If the named group does not exist, return 0
;
function h5video::H5G_OPEN, loc_id, group

  COMPILE_OPT IDL2, HIDDEN

  catch, error
  if (error ne 0L) then begin
     catch, /cancel
     return, 0L
  endif

  return, h5g_open(loc_id, group)
end


;;;;;
;
; h5video::SetProperty
;
pro h5video::SetProperty, group = group, $
                          index = index, $
                          stepsize = stepsize, $
                          metadata = metadata, $
                          file_metadata = file_metadata

  COMPILE_OPT IDL2, HIDDEN

  catch, error
  if (error ne 0L) then begin
     gid = 0L
     catch, /cancel
  endif
  
  ;; Open an existing group or create a new one
  if isa(group, 'string') && (group ne self.group) then begin
     gid = self.h5g_open(self.fid, group) ; try existing group
     if (gid eq 0L) && ~self.readonly then begin
        gid = h5g_create(self.fid, group) ; ...or new group
        self.timestamp, gid
     endif
     if (gid gt 0L) then begin  ; switch if successful
        h5g_close, self.gid
        self.gid = gid
        self.group = group
        self.ndx = 0L           ; start with first image of new group
     endif
  endif

  if isa(index, /number, /scalar) then begin
     ndx = self.checkindex(index)
     if (ndx ge 0L) then $
        self.ndx = ndx
  endif

  if isa(stepsize, /number, /scalar) then $
     self.step = long(stepsize) > 1L

  if isa(metadata) && ~self.readonly then begin
     tid = h5t_idl_create(metadata)
     sid = h5s_create_simple(1)
     aid = h5a_create(self.gid, 'metadata', tid, sid)
     h5a_write, aid, metadata
     h5a_close, aid
     h5s_close, sid
     h5t_close, tid
  endif

  if isa(file_metadata) && ~self.readonly then begin
     tid = h5t_idl_create(file_metadata)
     sid = h5s_create_simple(1)
     aid = h5a_create(self.fid, 'metadata', tid, sid)
     h5a_write, aid, file_metadata
     h5a_close, aid
     h5s_close, sid
     h5t_close, tid
  endif
end

;;;;;
;
; h5video::GetProperty
;
pro h5video::GetProperty, filename = filename, $
                          group = group, $
                          index = index, $
                          stepsize = stepsize, $
                          metadata = metadata, $
                          file_metadata = file_metadata, $
                          nimages = nimages, $
                          names = names, $
                          images = images, $ ;; dump all images?
                          readonly = readonly

  COMPILE_OPT IDL2, HIDDEN

  if arg_present(filename) then $
     filename = self.filename
  
  if arg_present(group) then $
     group = self.group

  if arg_present(index) then $
     index = self.ndx

  if arg_present(stepsize) then $
     stepsize = self.step

  if arg_present(metadata) then begin
     aid = self.h5a_open_name(self.gid, 'metadata')
     if (aid gt 0L) then begin
        metadata = h5a_read(aid)
        h5a_close, aid
     endif else $
        metadata = !NULL
  endif

  if arg_present(file_metadata) then begin
     aid = self.h5a_open_name(self.fid, 'metadata')
     if (aid gt 0L) then begin
        file_metadata = h5a_read(aid)
        h5a_close, aid
     endif else $
        file_metadata = !NULL
  endif
  
  if arg_present(nimages) then $
     nimages = h5g_get_num_objs(self.gid)

  if arg_present(names) then begin
     nimages = h5g_get_num_objs(self.gid)
     names = strarr(nimages)
     for n = 0, nimages-1 do $
        names[n] = h5g_get_obj_name_by_idx(self.gid, n)
  endif

  if arg_present(images) then begin
     nimages = h5g_get_num_objs(self.gid)
     images = list()
     for n = 0, nimages-1 do begin
        name = h5g_get_obj_name_by_idx(self.gid, n)
        images.add, self.read(name)
     endfor
  endif

  if arg_present(readonly) then $
     readonly = self.readonly
end

;;;;;
;
; h5video::Close
;
pro h5video::Close

  COMPILE_OPT IDL2, HIDDEN

  obj_destroy, self
end

;;;;;
;
; h5video::Cleanup
;
pro h5video::Cleanup

  COMPILE_OPT IDL2, HIDDEN

  if (self.sid gt 0) then h5s_close, self.sid
  if (self.tid gt 0) then h5t_close, self.tid
  if (self.gid gt 0) then h5g_close, self.gid
  if (self.fid gt 0) then h5f_close, self.fid
end

;;;;;
;
; h5video::Init()
;
function h5video::Init, filename, $
                        image = image, $
                        metadata = metadata, $
                        overwrite = overwrite, $
                        write = write, $
                        index = index, $
                        step = step

  COMPILE_OPT IDL2, HIDDEN

  catch, error                  ; catch error if file cannot be created
  if (error ne 0L) then begin
     catch, /cancel
     message, !ERROR_STATE.MSG, /inf
     if isa(self.fid) && (self.fid gt 0) then $
        h5f_close, self.fid
     return, 0B
  endif
  
  self.filename = isa(filename, 'string') ? filename : 'h5video.h5'
  if file_test(self.filename) then begin ; file exists
     if keyword_set(overwrite) then begin
        self.readonly = 0L
        file_delete, self.filename
        self.fid = h5f_create(self.filename) ; ... so overwrite it
        self.timestamp, self.fid
     endif else if (h5f_is_hdf5(self.filename)) then begin
        self.readonly = ~keyword_set(write)
        self.fid = h5f_open(self.filename, $ ; ... or open it, if it's HDF5
                            write = ~self.readonly)
     endif else begin                        ; ... or fail
        message, 'Could not open '+self.filename+': not an HDF5 file', /inf
        return, 0B
     endelse
  endif else begin                        ; file does not exist
     self.fid = h5f_create(self.filename) ; ... so create new HDF5 file
     self.timestamp, self.fid
  endelse

  self.group = 'images'         ; every video has images
  gid = self.h5g_open(self.fid, self.group)
  if (gid eq 0L) then begin
     gid = h5g_create(self.fid, self.group)
     if (gid gt 0L) then self.timestamp, gid
  endif
  if (gid eq 0L) then begin
     h5f_close, self.fid
     return, 0B
  endif
  self.gid = gid

  if isa(image, /number, /array) then $
     self.write, image

  if isa(metadata) && ~self.readonly then begin
     tid = h5t_idl_create(metadata)
     sid = h5s_create_simple(1)
     aid = h5a_create(self.fid, 'metadata', tid, sid)
     h5a_write, aid, metadata
     h5a_close, aid
     h5s_close, sid
     h5t_close, tid
  endif

  self.index = isa(index, /number, /scalar) ? long(index) > 0L : 0L
  
  self.step = isa(stepsize, /number, /scalar) ? long(stepsize) > 1L : 1L

  return, 1B
end

;;;;;
;
; h5video__define
;
pro h5video__define

  COMPILE_OPT IDL2, HIDDEN

  struct = {h5video, $
            inherits IDL_Object, $
            filename: '', $
            group: '', $        ; name of active group
            fid: 0L, $          ; file id
            tid: 0L, $          ; data type id
            sid: 0L, $          ; dataspace id
            gid: 0L, $          ; group id,
            ndx: 0L, $          ; index of current image
            step: 0L, $         ; number of frames to advance per step
            readonly:0L $       ; read-only flag
           }
end
