#ifndef ASSEMBLY_H
#define ASSEMBLY_H

extern struct asm_instruction{
	const char *assign;
	const char *output, *input;
	const char *eql, *nql, *lss, *grt;
	const char *add, *sub, *mul, *div;
} g_asm_instructions[2];

#endif // ASSEMBLY_H
