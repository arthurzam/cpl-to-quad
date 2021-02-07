#include "assembly.h"

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
