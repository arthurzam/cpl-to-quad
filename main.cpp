#include <iostream>
#include <cassert>

#include "driver.h"
#include "parser.hpp"

using namespace std;

driver::driver ()
{
}

int
driver::parse (const std::string &f)
{
  file = f;
  location.initialize(&file);
  scan_begin();
  yy::parser parse(*this);
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

void driver::backpatch(const std::vector<int> &list, int addr) {
	std::string dst = std::to_string(addr);
	for (int i : list) {
		if (i - 1 < code.size()) {
			assert(code[i - 1].operand1 == OPERAND_PLACEHOLDER);
			code[i - 1].operand1 = dst;
		}
	}
}

ostream &operator<<(ostream &os, const driver &drv) {
	for (const auto &inst : drv.code) {
		os << inst.op;
		if (inst.operand1.size() > 0)
			os << " " << inst.operand1;
		if (inst.operand2.size() > 0)
			os << " " << inst.operand2;
		if (inst.operand3.size() > 0)
			os << " " << inst.operand3;
		os << std::endl;
	}
	return os;
}


int main()
{
	driver drv;
	drv.parse("-");
	std::cout << drv;
	return 0;
}
