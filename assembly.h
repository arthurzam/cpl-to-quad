#ifndef ASSEMBLY_H
#define ASSEMBLY_H

#include "declarations.h"


namespace opcodes {
    struct asm_instruction {
        const char *assign;
        const char *output, *input;
        const char *eql, *nql, *lss, *grt;
        const char *add, *sub, *mul, *div;

        const char *get_op(ARITHMETIC_OPS op) const;
    };

    const asm_instruction& typed_ops(VAR_TYPE type);
};

#endif // ASSEMBLY_H
