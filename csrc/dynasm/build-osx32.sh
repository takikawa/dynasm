gcc -arch i386 -O2 dasm_x86.c -shared -install_name @loader_path/libdasm.dylib -o ../../bin/osx32/libdasm.dylib -DDASM_CHECKS
