command! -nargs=0   NebulaPutLazy    call nebula#put_lazy()
command! -nargs=0 -bang   NebulaPutConfig    call nebula#put_config(<bang>0)
command! -nargs=0 -bang   NebulaYankOptions    call nebula#yank_options(<bang>0)
command! -nargs=0   NebulaPutFromClipboard    call nebula#put_from_clipboard()
