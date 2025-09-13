// Simple module adding two numbers, used to demonstrate the test system
module Adder(
    input int a,
    input int b,

    output int sum
);
    assign sum = a + b;
endmodule