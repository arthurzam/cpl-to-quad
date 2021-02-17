#include <iostream>

#include "driver.h"

int main(int argc, char *argv[])
{
	driver drv;
	drv.parse(argc > 1 ? argv[1] : "-");
	drv.optimize();
	std::cout << drv;
	return 0;
}
