;+
; NAME:
;    mplayer
;
; PURPOSE:
;    Simple resizable GUI movie player that demonstrates the 
;    capabilities of the DGGgrMPlayer object.
;
; CATEGORY:
;    Multimedia
;
; CALLING SEQUENCE:
;    mplayer, filename
;    mplayer, player
;
; INPUTS:
;    If no argument is provided, a file selection dialog appears.
;
;    filename: String containing the name of a video file.
;    player: object of type DGGgrMPlayer
;
; KEYWORD PARAMETERS:
;    dimensions: [w,h] scaled dimensions of video frame.
;        Default: intrinsic dimensions
;
; KEYWORD FLAGS:
;    These options do not apply when a player object is provided.
;
;    greyscale (or grayscale): If set, cast video to greyscale.
;        Default: RGB color
;
;    order: If set, flip frames vertically
;        Default: ORDER = 1.
;
; SIDE EFFECTS:
;    Creates a GUI interface on the working screen.
;
; RESTRICTIONS:
;    Works for any kind of movie file supported by the open-source
;    mplayer suite of video playing software.
;
; EXAMPLE:
;    To play an NTSC VOB file from a DVD:
;
;    IDL> mplayer, 'myvob.VOB', dimensions=[640,480], /grey
;
; MODIFICATION HISTORY:
; 05/07/2012 Written by David G. Grier, New York University
; 05/09/2012 DGG Do not update with blank (black) image at EOF.
;    Make ORDER = 1 the default.
; 07/03/2012 DGG Updated for consistency with revisions to
;    DGGgrMPlayer.
; 07/05/2012 DGG Further consistency upgrades.  Fixed code for
;    parsing ORDER keyword.
; 07/24/2013 DGG Allow "gray" as well as "grey".
; 07/26/2013 DGG compatibility with new DGGgrMPlayer syntax.
;    Handle file selection more gracefully.
; 07/27/2013 DGG allow player as argument.
; 07/31/2013 DGG do not delete provided player object.
;
; Copyright (c) 2012-2013 David G. Grier
;-
;;;;;
;
; MPlayer_Event
;
; Process the XMANAGER event queue
;
pro mplayer_event, event

COMPILE_OPT IDL2, HIDDEN

widget_control, event.top, get_uvalue = s

case tag_names(event, /structure_name) of
   'WIDGET_TIMER': begin
      if (*s).pause ne 0 then begin
         (*s).pause = 0 
      endif else if (*s).player.eof then begin
         (*s).pause = 1
      endif else begin
         widget_control, event.top, timer = (*s).timer
         (*s).player->read
         if ~(*s).player.eof then $
            (*s).im->putdata, (*s).player.data
      endelse
   end

   'WIDGET_BUTTON': begin
      widget_control, event.id, get_uvalue = uval
      case uval of
         'PLAY': begin
            (*s).pause = 0
            widget_control, event.top, timer = (*s).timer
         end
         'PAUSE': (*s).pause = 1
         'STEP': begin
            (*s).pause = 1
            (*s).player->read
            if ~(*s).player.eof then $
               (*s).im->putdata, (*s).player.data
         end
         'REWIND': begin
            (*s).player.rewind
            (*s).pause = 1
            (*s).im->putdata, (*s).player.read()
         end
         'DONE': begin
            widget_control, event.top, /destroy
            return
         end
         else:
      endcase
   end
   
   'WIDGET_BASE': begin
      widget_control, event.id, tlb_get_size = newsize
      xy = newsize - (*s).pad
      widget_control, (*s).wimage, $
                      draw_xsize = xy[0], draw_ysize = xy[1], $
                      scr_xsize = xy[0], scr_ysize = xy[1]
   end

   else:
endcase
widget_control, (*s).wframe, $
                set_value = 'frame:'+string((*s).player.framenumber)
end

;;;;;
;
; MPlayer_Cleanup
;
pro mplayer_cleanup, w

COMPILE_OPT IDL2, HIDDEN

widget_control, w, get_uvalue = s
if ~(*s).noclobber then $
   obj_destroy, (*s).player
ptr_free, s
end

;;;;;
;
; MPlayer
;
; The main routine
;
pro mplayer, filename, $
             greyscale = greyscale, $
             grayscale = grayscale, $
             dimensions = dimensions, $
             order = order

COMPILE_OPT IDL2

umsg = 'USAGE: mplayer, filename, [/gray], [dimensions = dimensions], [/order]'

if n_params() ne 1 then begin
   filter = [['*.VOB', '*.mpg;mpeg', '*.avi', '*.m4v;*.mov', '*.*'], $
             ['VOB', 'MPEG', 'AVI', 'Quicktime', 'All files']]
   filename = dialog_pickfile(title = 'Select video file to play', $
                              /read, /must_exist, filter = filter)
endif

if isa(filename, 'DGGgrMPlayer') then begin
   player = filename
   noclobber = 1                ; do not delete provided player
endif else begin
   noclobber = 0
   if ~isa(filename, 'string') then begin
      message, umsg, /inf
      message, 'FILENAME must be a string', /inf
      return
   endif

   if ~file_test(filename, /read) then begin
      message, umsg, /inf
      message, 'could not read '+filename, /inf
      return
   endif

   ;; Create player object
   gray = keyword_set(grayscale) or keyword_set(greyscale)
   order = (arg_present(order)) ? keyword_set(order) : 1 ; flip by default
   
   player = DGGgrMPlayer(filename, greyscale=gray, dimensions=dimensions, order=order)
   if ~isa(player, 'DGGgrMPlayer') then begin
      message, umsg, /inf
      message, 'could not open '+filename, /inf
      return
   endif
endelse

; Define widget hierarchy
base = widget_base(/column, title = 'MPlayer', /tlb_size_events)

wimage = widget_window(base, uvalue = 'image', uname = 'IMAGE')

; info and buttons
bar = widget_base(base, /row, /grid_layout)
info = widget_base(bar, /column, /align_left)
buttons = widget_base(bar, /row)

wframe = widget_label(info, value = 'frame: 0', /dynamic_resize, $
                      /sunken_frame)

void   = widget_button(buttons, value = 'Play',   uvalue = 'PLAY')
void   = widget_button(buttons, value = 'Pause',  uvalue = 'PAUSE')
void   = widget_button(buttons, value = 'Step',   uvalue = 'STEP')
void   = widget_button(buttons, value = 'Rewind', uvalue = 'REWIND')
void   = widget_button(buttons, value = 'Done',   uvalue = 'DONE')

; realize the widgets
widget_control, base, /realize

xmanager, 'mplayer', base, /no_block, cleanup = 'mplayer_cleanup'

widget_control, wimage, get_value = win
win.select
im = image(player.read(), margin = 0, /current)

widget_control, base, tlb_get_size = basesize
xpad = basesize[0] - 640
ypad = basesize[1] - 512
pad = [xpad, ypad]

; state variable
timer = 1./player.fps
s = {player:    player,    $
     noclobber: noclobber, $ 
     im:        im,        $
     wimage:    wimage,    $
     wframe:    wframe,    $
     pad:       pad,       $
     pause:     0,         $
     timer:     timer}
ps = ptr_new(s, /no_copy)

widget_control, base, set_uvalue = ps, /no_copy

widget_control, base, timer = timer

end
