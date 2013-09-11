command! -nargs=0   NebulaPutLazy    call nebula#put_lazy()
command! -nargs=0 -bang   NebulaPutCongig    call nebula#put_config(<bang>0)
command! -nargs=0 -bang   NebulaYankOptions    call nebula#yank_options(<bang>0)
