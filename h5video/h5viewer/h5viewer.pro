;;;;;
;
; h5viewer_normalize
;
function h5viewer_normalize, video

  COMPILE_OPT IDL2, HIDDEN

  index = video.index
  image = float(video.read(index))
  video.group = 'background'
  bg = float(video.read(index))
  video.group = 'images'
  return, byte(100.*(image/bg) < 255.)
end

;;;;;
;
; h5viewer_draw
;
pro h5viewer_draw, state

  COMPILE_OPT IDL2, HIDDEN

  video = state['video']
  index = video.index

  case state['style'] of
     0: data = video.read(index)         ; raw images
     1: data = video.read(index)         ; already looking at background group
     2: data = h5viewer_normalize(video) ; normalized
     3: begin                            ; circletransformed image
        image = h5viewer_normalize(video)
        data = bytscl(circletransform(image))
     end
     4: begin                            ; labeled regions
        image = h5viewer_normalize(video)
        ct = circletransform(image)
        res = moment(ct, maxmoment = 2)
        threshold = res[0] + 3.*sqrt(res[1])
        data = label_region(ct ge threshold)
     end

     else:
  endcase

  widget_control, state['slider'], set_value = index
  state['image'].setproperty, data = data
  state['screen'].draw
  video.index = index + 1
end

;;;;;
;
; h5viewer_setstyle
;
function h5viewer_setstyle, event

  COMPILE_OPT IDL2, HIDDEN

  if event.select then begin
     widget_control, event.top, get_uvalue = state
     state['style'] = event.value
     index = state['video'].index
     state['video'].group = (event.value eq 1) ? 'background' : 'images'
     state['video'].index = (index - 1) > 0L
     state['image'].setproperty, palette = (event.value eq 4) ? $
                                           state['rgb'] : state['grey']
     h5viewer_draw, state
  endif
  
  return, 0
end

;;;;;
;
; h5viewer_event
;
pro h5viewer_event, event

  COMPILE_OPT IDL2, HIDDEN

  widget_control, event.top, get_uvalue = state

  redraw = 1                    ; don't redraw on PAUSE or QUIT
  case tag_names(event, /structure_name) of
     'WIDGET_TIMER': begin
        if state['playing'] then $
           widget_control, event.top, timer = 1./30.
     end
     
     'WIDGET_BUTTON': begin
        widget_control, event.id, get_uvalue = uvalue
        case uvalue of
           'PLAY': begin
              state['playing'] = 1
              widget_control, event.top, timer = 1./30.
           end

           'STEP': state['playing'] = 0
           
           'PAUSE': begin
              state['playing'] = 0
              redraw = 0
           end           

           'BACK': begin
              state['playing'] = 0
              state['video'].index = state['video'].index - 2
           end
           
           'REWIND': state['video'].index = 0

           'OPEN':begin
              state['playing'] = 0
              file = state['file']
              state.remove, 'file'
              h5viewer_openvideo, state
              if state.haskey('error') then begin
                 message, state['error'], /inf
                 message, 'Reverting to '+file_basename(file), /inf
                 state['file'] = file
                 state.remove, 'error'
                 redraw = 0
              endif
              ;;; FIXME: Resize graphics and widgets!!!
           end
           
           'QUIT': begin
              state['playing'] = 0
              redraw = 0
              widget_control, event.top, /destroy
           end
           
           else: begin
              print, uvalue
              help, event
              end
        endcase
     end
     
     'WIDGET_SLIDER': begin
        state['playing'] = 0
        widget_control, event.id, get_value = index
        state['video'].index = index
     end

     else: begin
        print, tag_names(event, /structure_name)
        help, event
        end
  endcase
  
  if redraw then h5viewer_draw, state
end

;;;;;
;
; h5viewer_cleanup
;
pro h5viewer_cleanup, tlb

  COMPILE_OPT IDL2, HIDDEN

  widget_control, tlb, get_uvalue = state, /no_copy

  if isa(state['video'], 'h5video') then $
     state['video'].close
end

;;;;;
;
; h5viewer_openvideo
;
pro h5viewer_openvideo, state

  COMPILE_OPT IDL2

  suffix = '.h5'
  if ~state.haskey('file') then begin
     file = dialog_pickfile(/read, $
                            filter = '*'+suffix, /fix_filter, $
                            default_extension = suffix, $
                            title = 'Select h5video file')
     
     state['file'] = file[0]
  endif

  file = state['file']
  name = file_basename(file, suffix)
  if (name eq suffix) || (strlen(name) eq 0) then begin
     state['error'] = 'ERROR: No file specified'
     return
  endif
  
  if file_search(file, /test_regular, /test_read) then begin
     video = h5video(file, /quiet)
     if ~isa(video, 'h5video') then begin
        state['error'] = 'ERROR: ' + file + ' is not an h5video file'
        return
     endif
  endif else begin
     state['error'] = 'ERROR: Could not find ' + file
     return
  endelse

  state['video'] = video
  video.read                    ; load first image
end

;;;;;
;
; h5viewer_widgets
;
pro h5viewer_widgets, state

  COMPILE_OPT IDL2, HIDDEN

  wtop = widget_base(/column, title = 'H5Player', mbar = bar)

  ;;; File menu
  file_menu = widget_button(bar, value = 'File', /menu)
  void = widget_button(file_menu, value = 'Open', uvalue = 'OPEN')
  void = widget_button(file_menu, value = 'Quit', uvalue = 'QUIT')

  ;;; FIXME set screen size
  dimensions = state['video'].dimensions
  xsize = dimensions[0] < 640
  ysize = dimensions[0] < 480
  wscreen = widget_draw(wtop, frame = 1, $
                        graphics_level = 2, $
                        xsize = dimensions[0] < xsize, $
                        ysize = dimensions[1] < ysize)

  ;; buttons
  wradio = cw_bgroup(wtop, ['I(r)', 'I0(r)', 'b(r)', 'c(r)', 'fn(r)'], $
                     set_value = 0, /exclusive, /return_index, $
                     /row, ypad = 0, $
                     event_func = 'h5viewer_setstyle')
  wcontrols = widget_base(wtop, /frame, xsize = xsize, $
                          /row, ypad = 0, /base_align_bottom)
  wbuttons = widget_base(wcontrols, /row, /grid_layout, ypad = 0)
  void = widget_button(wbuttons, value = 'Rewind', uvalue = 'REWIND')
  void = widget_button(wbuttons, value = 'Back', uvalue = 'BACK')
  void = widget_button(wbuttons, value = 'Pause', uvalue = 'PAUSE')
  void = widget_button(wbuttons, value = 'Step', uvalue = 'STEP')
  void = widget_button(wbuttons, value = 'Play', uvalue = 'PLAY')

  ;; slider
  top_geom = widget_info(wtop, /geometry)
  but_geom = widget_info(wbuttons, /geometry)
  scr_geom = widget_info(wscreen, /geometry)
  slider_size = scr_geom.xsize - but_geom.xsize - top_geom.xpad
  wslider = widget_slider(wcontrols, $
                          xsize = slider_size, $
                          minimum = 0, maximum = state['video'].nimages-1, $
                          /drag)
  
  ;;; realize widget hierarchy
  widget_control, wtop, /realize
  widget_control, wscreen, get_value = screen

  state['screen'] = screen
  state['slider'] = wslider
  widget_control, wtop, set_uvalue = state

  xmanager, 'h5viewer', wtop, /no_block, cleanup = 'h5viewer_cleanup'
end

;;;;;
;
; h5viewer_graphics
;
pro h5viewer_graphics, state

  COMPILE_OPT IDL2, HIDDEN
  
  image = IDLgrImage(state['video'].data, /interpolate)
  imagemodel = IDLgrModel()
  imagemodel.add, image
  imageview = IDLgrView(viewplane_rect = [0, 0, state['video'].dimensions])
  imageview.add, imagemodel
  scene = IDLgrScene()
  scene.add, imageview

  ;;; color tables for images
  grey = IDLgrPalette()
  grey.loadct, 0                ; greyscale
  rgb = IDLgrPalette()
  rgb.loadct, 38                ; lots of colors
  rgb.getproperty, red = r, green = g, blue = b
  r[0] = 128                    ; medium grey background
  g[0] = 128
  b[0] = 128
  rgb.setproperty, red = r, green = g, blue = b

  image.setproperty, palette = (state['style'] eq 4) ? rgb : grey

  ;;; update system state
  state['image'] = image
  state['grey'] = grey
  state['rgb'] = rgb

  ;;; install graphics within widget hierarchy
  state['screen'].setproperty, graphics_tree = scene
end

;;;;;
;
; h5viewer
;
pro h5viewer, h5file

  COMPILE_OPT IDL2

  state = hash()

  ;;; open video file
  if n_params() eq 1 then $
     state['file'] = h5file

  h5viewer_openvideo, state
  if state.haskey('error') then begin
     message, state['error'], /inf
     return
  endif
  
  state['style'] = 0            ; start by showing raw images

  ;;; create widget hierarchy and start event loop
  h5viewer_widgets, state
  
  ;;; create and install graphics hierarchy
  h5viewer_graphics, state

  ;;; draw first image
  h5viewer_draw, state
end
