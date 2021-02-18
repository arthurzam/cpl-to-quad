#include <iostream>

#include "driver.h"

int main(int argc, char *argv[])
{
    driver drv(argc > 1 ? argv[1] : "/home/arthur/dev/build/build-cpq-Desktop-Release/test.cpl");
    if (drv.parse()) {
        drv.optimize();
        std::cout << drv;
    } else {
        std::cerr << "Bad file" << std::endl;
    }
    return 0;
}
