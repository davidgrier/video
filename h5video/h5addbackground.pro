pro h5addbackground, h5file, order

  video = h5video(h5file, /write)
  if ~isa(video, 'h5video') then $
     return
  
  median = vmedian(order = order)
  if ~isa(median, 'vmedian') then $
     return

  for n = 0, video.nimages - 1 do begin
     video.group = 'images'
     median.add, video.read(n)
     name = video.name(n)
     video.group = 'background'
     video.write, median.get(), name
     print, n, name
  endfor

  obj_destroy, video
  obj_destroy, median
end

