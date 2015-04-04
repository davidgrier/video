pro h5viewer_menu, bar

  COMPILE_OPT IDL2, HIDDEN

  ;;; FILE MENU
  file_menu = widget_button(bar, value = 'File', /menu)
  void = widget_button(file_menu, value = 'Quit', uvalue = 'QUIT')
end
