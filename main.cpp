#include <iostream>

#include "driver.h"

int main(int argc, char *argv[])
{
	driver drv;
	drv.parse(argc > 1 ? argv[1] : "-");
	if (drv) {
		drv.optimize();
		std::cout << drv;
	} else {
		std::cerr << "Bad file" << std::endl;
	}
	return 0;
}
