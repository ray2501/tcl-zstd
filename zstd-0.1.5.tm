# Zstandard bindings/demo for Tcl.
# Copyright (c) 2017 dbohdan.
# License: MIT.
# If you installed libzstd.so.1 to /usr/local/lib/ on *nix, you may need to
# run Tcl with /usr/local/lib/ in $LD_LIBRARY_PATH. E.g.,
# $ LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/lib" tclsh zstd.tcl
# in the POSIX shell or
# > env "LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib" tclsh zstd.tcl
# in fish.
package require critcl 3

if {![::critcl::compiling]} {
    error {critcl found no compiler}
}

namespace eval ::zstd {
    variable bindingsVersion 0.1.5
    variable version {}
}
critcl::ccode {
    #include <zstd.h>
}
critcl::clibraries -lzstd

critcl::cinit {
    int version = ZSTD_versionNumber();
    char s[32];
    Tcl_CreateNamespace(ip, "::zstd", NULL, NULL);
    sprintf(s, "%d.%d.%d", version / 10000, version / 100 % 100, version % 100);
    Tcl_SetVar2Ex(ip, "::zstd::version", NULL, Tcl_NewStringObj(s, -1), 0);
} {}

critcl::ccommand zstd::compress {cdata interp objc objv} {
    int level = 1;
    int max_level = ZSTD_maxCLevel();
    void *source_buf;
    void *dest_buf;
    int source_len;
    size_t dest_size;
    size_t compressed_size;

    if (objc != 2 && objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "data ?level?");
        return TCL_ERROR;
    }
    if (objc == 3) {
        int rc = Tcl_GetIntFromObj(interp, objv[2], &level);
        if (rc != TCL_OK || ((level < 1) || (level > max_level))) {
            Tcl_SetObjResult(interp,
                             Tcl_ObjPrintf("level must be integer between "
                                           "1 and %d", max_level));
            return TCL_ERROR;
        }
    }

    source_buf = (void *)Tcl_GetByteArrayFromObj(objv[1], &source_len);
    dest_size = ZSTD_compressBound(source_len);
    dest_buf = malloc(dest_size);
    if (dest_buf == NULL) {
        Tcl_SetObjResult(interp,
                         Tcl_NewStringObj("can't allocate memory to compress "
                                          "data", -1));
        return TCL_ERROR;
    }

    compressed_size = ZSTD_compress(dest_buf, dest_size, source_buf,
                                    source_len, level);
    if (ZSTD_isError(compressed_size)) {
            Tcl_SetObjResult(interp,
                             Tcl_ObjPrintf("zstd encoding error: %s",
                                           ZSTD_getErrorName(compressed_size)));
            return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, Tcl_NewByteArrayObj(dest_buf, compressed_size));
    free(dest_buf);

    return TCL_OK;
}

critcl::ccommand zstd::decompress {cdata interp objc objv} {
    void *source_buf;
    void *dest_buf;
    int source_len;
    unsigned long long dest_size;
    size_t decompressed_size;

    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "data");
        return TCL_ERROR;
    }

    source_buf = (void *)Tcl_GetByteArrayFromObj(objv[1], &source_len);
    dest_size = ZSTD_getDecompressedSize(source_buf, source_len);
    if (dest_size == 0) {
        Tcl_SetObjResult(interp, Tcl_NewStringObj("invalid data", -1));
        return TCL_ERROR;
    }
    dest_buf = malloc(dest_size);
    if (dest_buf == NULL) {
        Tcl_SetObjResult(interp,
                         Tcl_NewStringObj("can't allocate memory to decompress "
                                          "data", -1));
        return TCL_ERROR;
    }

    decompressed_size = ZSTD_decompress(dest_buf, dest_size, source_buf,
                                        source_len);
    if (decompressed_size != dest_size) {
        Tcl_SetObjResult(interp,
                         Tcl_ObjPrintf("zstd decoding error: %s",
                                       ZSTD_getErrorName(decompressed_size)));
        return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, Tcl_NewByteArrayObj(dest_buf, decompressed_size));
    free(dest_buf);

    return TCL_OK;
}

# If this is the main script...
if {[info exists argv0] && ([file tail [info script]] eq [file tail $argv0])} {
    {*}$auto_index(zstd::compress)
    puts "zstd version $zstd::version"

    puts [zstd::decompress [zstd::compress hello!]]

    set ch [open [info script] rb]
    set x [read $ch]
    close $ch

    if {[catch {package require md5}]} {
        puts {no package "md5" found -- skipping test}
    } else {
        set checksum1 [::md5::md5 -hex $x]
        set y [zstd::compress $x]
        set checksum2 [::md5::md5 -hex [zstd::decompress $y]]
        if {$checksum1 ne $checksum2} {
            error {decompressed data differs from original}
        }
    }

    set z [string repeat $x 10000]
    puts [string length $z]
    zstd::compress $z
    foreach level {1 2 3 5 10 19} {
        puts [format {level=%1$2d   size=%3$d   %2$s} \
                $level \
                [time {
                    set size [string length [zstd::compress $z $level]]
                } 10] \
                $size]
    }
}
