module tb;
  initial begin
    assert(1 == 1) else begin
      $error("1 is not equal to 1");
    end

    assert(2 + 2 == 4) else begin
      $error("2 + 2 is equal to 4");
    end

    assert(2 * 2 != 5) else begin
      $error("2 * 2 is not equal to 5");
    end

    $finish;
  end
endmodule
