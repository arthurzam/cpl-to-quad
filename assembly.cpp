#include "assembly.h"

using namespace opcodes;

struct asm_instruction g_asm_instructions[2] = {
{
    .assign = "IASN",
    .output = "IPRT",
    .input = "IINP",
    .eql = "IEQL",
    .nql = "INQL",
    .lss = "ILSS",
    .grt = "IGRT",
    .add = "IADD",
    .sub = "ISUB",
    .mul = "IMLT",
    .div = "IDIV",
},{
    .assign = "RASN",
    .output = "RPRT",
    .input = "RINP",
    .eql = "REQL",
    .nql = "RNQL",
    .lss = "RLSS",
    .grt = "RGRT",
    .add = "RADD",
    .sub = "RSUB",
    .mul = "RMLT",
    .div = "RDIV",
}
};

const char *asm_instruction::get_op(ARITHMETIC_OPS op) const {
    switch (op) {
        case ARITHMETIC_OPS::ADD: return add;
        case ARITHMETIC_OPS::SUB: return sub;
        case ARITHMETIC_OPS::MUL: return mul;
        case ARITHMETIC_OPS::DIV: return div;
        default: return add;
    }
}

const opcodes::asm_instruction &opcodes::typed_ops(VAR_TYPE type) {
    if (type == VAR_TYPE::FLOAT)
        return g_asm_instructions[1];
    else
        return g_asm_instructions[0];
}
