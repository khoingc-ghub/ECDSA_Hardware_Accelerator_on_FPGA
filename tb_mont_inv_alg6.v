`timescale 1ns/1ps

module tb_mont_inv_alg6;

  // === Tham số ===
  parameter WIDTH = 256;
  // === Ngõ vào / ra ===
  reg                  clk, rst_n, start;
  reg  [WIDTH-1:0]     a, p, M;
  wire [WIDTH-1:0]     r_out;
  wire                 done;

  // === Khai báo DUT ===
  // Thay MODULE_NAME bằng tên module bạn viết cho Algorithm 6
  mont_inv_alg6 #(.N(WIDTH)) dut (
    .clk(clk),
    .reset(rst_n),
    .start(start),
    .a(a),
    .p(p),
    .M(M),
    .r(r_out),
    .done(done)
  );

  // === Clock 10ns ===
  always #5 clk = ~clk;

  // === Khởi tạo ===
  initial begin
    clk   = 0;
    rst_n = 0;
    start = 0;
    a     = 0;
    p     = 0;
    M     = 0;

    // reset
    #20;
    rst_n = 1;

    
    // --- set dữ liệu test ---
    // p là số nguyên tố 256-bit (secp256k1)
    p = 256'd115792089237316195423570985008687907853269984665640564039457584007908834671663;
    a = 256'd3;     // giá trị a cần kiểm tra nghịch đảo
    M = 256'd1;    // thường chọn M = 1
    
    // --- kích hoạt start ---
    #10;
    start = 1;
    #10;
    start = 0;

    // --- đợi done ---
    wait (done == 1);
    #10;

    // --- kiểm tra kết quả ---
    $display("==== Testcase a = %0d ====", a);
    $display("r_out = %0d", r_out);
    $display("(a * r_out) %% p = %0d", (a * r_out) % p);

    if ((a * r_out) % p == 1)
      $display("✅ SUCCESS: r_out là nghịch đảo của a mod p");
    else
      $display("❌ FAIL: r_out KHÔNG phải nghịch đảo");

    #20;
    $stop;
  end

endmodule
