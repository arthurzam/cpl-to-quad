#include <iostream>
#include <cassert>

#include "driver.h"
#include "parser.hpp"


driver::driver() { }

int driver::parse(const std::string &f) {
  file = f;
  location.initialize(&file);
  scan_begin();
  yy::parser parse(*this);
  //parse.set_debug_level (true);
  int res = parse();
  scan_end();
  return res;
}

void driver::gen(const char *op, const std::string &operand1, const std::string &operand2, const std::string &operand3) {
	nextinst++;
	this->code.emplace_back(op, operand1, operand2, operand3);
}

std::string driver::newtemp() {
	return "_t" + std::to_string(++tmp_counter);
}

void instruction::backpatch(const std::string &addr) {
	assert(operand1 == OPERAND_PLACEHOLDER);
	operand1 = addr;
}

void driver::backpatch(const std::vector<int> &list, int addr) {
	std::string dst = std::to_string(addr);
	for (int i : list) {
		assert(i - 1 < code.size());
		code[i - 1].backpatch(dst);
	}
}

std::pair<const std::string &, const std::string &> driver::auto_upcast(const std::string &tmp, const expression &first, const expression &second) {
	VAR_TYPE type = (first.type == VAR_TYPE::INT && second.type == VAR_TYPE::INT) ? VAR_TYPE::INT : VAR_TYPE::FLOAT;
	if (type != first.type) {
		gen("ITOR", tmp, first.addr);
		return {tmp, second.addr};
	} else if (type != second.type) {
		gen("ITOR", tmp, second.addr);
		return {first.addr, tmp};
	} else {
		return {first.addr, second.addr};
	}
}

std::ostream &operator<<(std::ostream &os, const instruction &inst) {
	os << inst.op;
	if (inst.operand1.size() > 0)
		os << " " << inst.operand1;
	if (inst.operand2.size() > 0)
		os << " " << inst.operand2;
	if (inst.operand3.size() > 0)
		os << " " << inst.operand3;
	return os;
}

std::ostream &operator<<(std::ostream &os, const driver &drv) {
	for (const auto &inst : drv.code)
		os << inst << std::endl;
	return os;
}
