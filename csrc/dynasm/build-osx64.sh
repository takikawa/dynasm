gcc -arch x86_64 -O2 dasm_x86.c -shared -install_name @loader_path/libdasm_x86.dylib -o ../../bin/osx64/libdasm_x86.dylib -DDASM_CHECKS
