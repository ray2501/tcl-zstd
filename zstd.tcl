# Zstandard bindings/demo for Tcl.
# Copyright (c) 2017-2018, 2020, 2024 D. Bohdan.
# License: MIT.

package require critcl 3.1.10

if {![critcl::compiling]} {
    error {critcl found no compiler}
}

namespace eval ::zstd {
    variable bindingsVersion 0.2.1
    variable version {}
}

critcl::ccode {
    #include <stdlib.h>
    #include <zstd.h>
}
if {[package vsatisfies [info patchlevel] 8]} {
    critcl::ccode {
        typedef int Tcl_Size;
    }
}
critcl::clibraries -lzstd

critcl::cinit {
    int version = ZSTD_versionNumber();
    char s[32];
    Tcl_CreateNamespace(ip, "::zstd", NULL, NULL);
    sprintf(s, "%d.%d.%d", version / 10000, version / 100 % 100, version % 100);
    Tcl_SetVar2Ex(ip, "::zstd::version", NULL, Tcl_NewStringObj(s, -1), 0);
} {}

critcl::ccommand ::zstd::compress {cdata interp objc objv} {
    int level = 1;
    int max_level = ZSTD_maxCLevel();
    void *source_buf;
    void *dest_buf;
    Tcl_Size source_len;
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

critcl::ccommand ::zstd::decompress {cdata interp objc objv} {
    void *source_buf;
    void *dest_buf;
    Tcl_Size source_len;
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

package provide zstd 0.2.1
