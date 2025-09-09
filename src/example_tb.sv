// This is an example testbench file.
// Is it quite rudimentary and not scalable, but it demonstrates basic functionality.
// For more complex testbenches, use other methodologies.

module example_module (
  input logic a,
  input logic b,
  output logic y
);
  assign y = a & b;
endmodule

module tb;
  logic a, b, y;
  example_module dut (.a(a), .b(b), .y(y));

  initial begin
    a = 0; b = 0;
    #1;
    assert(y == 0) else begin
      $error("y should be 0 when a and b are both 0");
    end

    a = 1; b = 0;
    #1;
    assert(y == 0) else begin
      $error("y should be 0 when a is 1 and b is 0");
    end

    a = 0; b = 1;
    #1;
    assert(y == 0) else begin
      $error("y should be 0 when a is 0 and b is 1");
    end

    a = 1; b = 1;
    #1;
    assert(y == 1) else begin
      $error("y should be 2 when a and b are both 1");
    end

    $finish;
  end
endmodule
