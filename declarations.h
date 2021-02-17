#ifndef DECLARATIONS_H
#define DECLARATIONS_H

#include <string>
#include <iostream>

enum class REL_OPS {
	EQ = 0,
	NE,
	LT,
	GT,
	LE,
	GE,
};

enum class ARITHMETIC_OPS {
	ADD = 0,
	SUB,
	MUL,
	DIV
};

enum class VAR_TYPE {
	INT = 0,
	FLOAT
};

#define OPERAND_PLACEHOLDER "@"
struct instruction {
	const char *op;
	std::string operand1;
	std::string operand2;
	std::string operand3;

	instruction(const char *op, std::string operand1, std::string operand2, std::string operand3) :
		op(op), operand1(std::move(operand1)), operand2(std::move(operand2)), operand3(std::move(operand3))
	{}

	void backpatch(const std::string &addr);

	friend std::ostream &operator<<(std::ostream &os, const instruction &inst);
};

#endif // DECLARATIONS_H
