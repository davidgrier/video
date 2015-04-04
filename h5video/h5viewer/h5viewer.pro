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
  video.index = index + 1
  
  return, byte(100.*(image/bg))
end

  
;;;;;
;
; h5viewer_draw
;
pro h5viewer_draw, state

  COMPILE_OPT IDL2, HIDDEN

  video = state['video']
  widget_control, state['slider'], set_value = video.index
  
  case state['style'] of
     'image': begin
        data = video.read()
     end

     'background': begin
        data = video.read() ; already looking at background group
     end

     'normalized': begin
        data = h5viewer_normalize(video)
     end

     'circletransformed': begin
        image = h5viewer_normalize(video)
        data = bytscl(circletransform(image))
     end
     
     else:
  endcase

  state['image'].setproperty, data = data
  state['screen'].draw
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
              state['video'].index = state['video'].index - 1
              h5viewer_draw, state
              state['video'].index = state['video'].index - 1
           end
           
           'REWIND': begin
              state['video'].index = 0
              h5viewer_draw, state
           end
           
           'QUIT': begin
              state['playing'] = 0
              widget_control, event.top, /destroy
           end
           
           else: help, event
        endcase
     end
     
     'WIDGET_SLIDER': begin
        state['playing'] = 0
        widget_control, event.id, get_value = index
        state['video'].index = index
        h5viewer_draw, state
     end

     else: help, event
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
  video = h5video(h5file)
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
  wcontrols = widget_base(wtop, /row, xsize = xsize, /frame)
  wbuttons = widget_base(wcontrols, /row, /grid_layout, uvalue = 'WBUTTONS')
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
  screen.draw

  ;;; current state of system
  state = hash()
  state['video'] = video
  state['image'] = image
  state['screen'] = screen
  state['slider'] = wslider
  state['style'] = 'circletransformed'
  widget_control, wtop, set_uvalue = state

  ;;; start event loop
  xmanager, 'h5viewer', wtop, /no_block, cleanup = 'h5viewer_cleanup'

  image.setproperty, data = a
  screen.draw
end

