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
     0: begin
        data = video.read(index)
     end

     1: begin
        data = video.read(index) ; already looking at background group
     end

     2: begin
        data = h5viewer_normalize(video)
     end

     3: begin
        image = h5viewer_normalize(video)
        data = bytscl(circletransform(image))
     end

     4: begin
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

  case tag_names(event, /structure_name) of
     'WIDGET_TIMER': begin
        if state['playing'] then begin
           widget_control, event.top, timer = 1./30.
           h5viewer_draw, state
        endif
     end
     
     'WIDGET_BUTTON': begin
        widget_control, event.id, get_uvalue = uval
        case uval of
           'PLAY': begin
              state['playing'] = 1
              widget_control, event.top, timer = 1./30.
              h5viewer_draw, state
           end

           'STEP': begin
              state['playing'] = 0
              h5viewer_draw, state
           end
           
           'PAUSE': state['playing'] = 0

           'BACK': begin
              state['playing'] = 0
              state['video'].index = state['video'].index - 2
              h5viewer_draw, state
           end
           
           'REWIND': begin
              state['video'].index = 0
              h5viewer_draw, state
           end
           
           'QUIT': begin
              state['playing'] = 0
              widget_control, event.top, /destroy
           end
           
           else: begin
              print, uval
              help, event
              end
        endcase
     end
     
     'WIDGET_SLIDER': begin
        state['playing'] = 0
        widget_control, event.id, get_value = index
        state['video'].index = index
        h5viewer_draw, state
     end

     else: begin
        print, tag_names(event, /structure_name)
        help, event
        end
  endcase
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
; h5viewer
;
pro h5viewer,  h5file

  COMPILE_OPT IDL2

  ;;; * check that file exists
  ;;; * open file dialog?
  video = h5video(h5file, /quiet)
  if ~isa(video, 'h5video') then begin
     message, 'Could not open '+h5file, /inf
     return
  endif
  a = video.read()
  dimensions = size(a, /dimensions)

  ;;; Widget layout
  wtop = widget_base(/column, title = 'H5Player', $
                     mbar = bar)

  h5viewer_menu, bar
  
  ;;; FIXME set screen size
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
                          minimum = 0, maximum = video.nimages-1, $
                          /drag)
  
  ;;; realize widget hierarchy
  widget_control, wtop, /realize
  widget_control, wscreen, get_value = screen

  ;;; graphics hierarchy
  image = IDLgrImage(a, /interpolate)
  imagemodel = IDLgrModel()
  imagemodel.add, image
  imageview = IDLgrView(viewplane_rect = [0, 0, dimensions])
  imageview.add, imagemodel
  scene = IDLgrScene()
  scene.add, imageview
  screen.setproperty, graphics_tree = scene

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

  ;;; current state of system
  state = hash()
  state['video'] = video
  state['image'] = image
  state['screen'] = screen
  state['slider'] = wslider
  state['style'] = 0
  state['grey'] = grey
  state['rgb'] = rgb
  widget_control, wtop, set_uvalue = state
  
  ;;; start event loop
  xmanager, 'h5viewer', wtop, /no_block, cleanup = 'h5viewer_cleanup'
  
  h5viewer_draw, state
end

