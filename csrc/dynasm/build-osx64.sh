gcc -arch x86_64 -O2 dasm_x86.c -shared -install_name @loader_path/libdasm.dylib -o ../../bin/osx64/libdasm.dylib -DDASM_CHECKS
