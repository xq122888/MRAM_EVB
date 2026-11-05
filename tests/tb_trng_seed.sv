`timescale 1ns/1ps
// Test-only primitive placeholder. Raw RO taps are explicitly driven below;
// no simulated oscillation or digital pattern is treated as physical entropy.
module LUT1 #(parameter [1:0] INIT=2'b00)(input I0,output O);
  assign O=1'b0;
endmodule

module tb_trng_conditioner;
  reg clk=0,rst_n=0;
  reg [4:0] raw_taps=0;
  integer mode=0,driver_count=0,valid_count=0;
  wire [7:0] data;
  wire valid,failed;
  always #2.5 clk=~clk;
  trng_8bit #(.SAMPLE_LOG2(2),.WATCHDOG_BITS(12)) dut(
    .clk(clk),.rst_n(rst_n),.rnd_data(data),.rnd_valid(valid),.health_fail(failed));
  initial force dut.ro_taps=raw_taps;
  always @(negedge clk) begin
    if(!rst_n) begin driver_count=0;raw_taps=0;end
    else begin
      case(mode)
        0:raw_taps=((driver_count/4)%4==1 || (driver_count/4)%4==2)?5'd1:5'd0;
        1:raw_taps=0;
        2:raw_taps=((driver_count/4)%16==15)?5'd1:5'd0;
        3:raw_taps=((driver_count/4)%4>=2)?5'd1:5'd0;
      endcase
      driver_count=driver_count+1;
    end
  end
  always @(posedge clk) begin
    #1;
    if(rst_n && valid) begin
      valid_count=valid_count+1;
      if(!dut.source_qualified) $fatal(1,"Entropy byte offered before startup health window");
      if(mode==0 && data!==8'h55 && data!==8'haa)
        $fatal(1,"Von Neumann extraction wrong: %h",data);
    end
  end
  task boot(input integer selected);
    begin rst_n=0;mode=selected;valid_count=0;repeat(4) @(negedge clk);rst_n=1;end
  endtask
  initial begin
    boot(0);repeat(1800) @(negedge clk);
    if(failed || valid_count<8) $fatal(1,"Healthy injected samples failed");
    boot(1);repeat(400) @(negedge clk);
    if(!failed) $fatal(1,"Stuck source was accepted");
    boot(2);repeat(1300) @(negedge clk);
    if(!failed) $fatal(1,"Biased source was accepted");
    boot(3);repeat(4500) @(negedge clk);
    if(!failed || valid_count!=0) $fatal(1,"Discarded-pair watchdog failed");
    $display("PASS: actual conditioner with injected raw samples; extraction, repetition, bias and no-output watchdog");
    $finish;
  end
  initial begin #100000;$fatal(1,"Conditioner watchdog expired");end
endmodule

module tb_trng_seed_pool;
  reg clk=0,rst_n=0,take=0,inject_valid=0,inject_fault=0;
  reg [7:0] inject_byte=0;
  wire [31:0] data;
  wire ready,failed;
  integer n;
  always #2.5 clk=~clk;
  mram_trng_seed dut(.clk(clk),.rst_n(rst_n),.take(take),
    .seed_data(data),.seed_ready(ready),.health_fail(failed));
  initial begin
    force dut.entropy_byte=inject_byte;
    force dut.entropy_valid=inject_valid;
    force dut.source_fail=inject_fault;
  end
  task byte_in(input [7:0] value);
    begin @(negedge clk);inject_byte=value;inject_valid=1;
      @(negedge clk);inject_valid=0;end
  endtask
  task word_in(input [31:0] value);
    begin byte_in(value[31:24]);byte_in(value[23:16]);byte_in(value[15:8]);byte_in(value[7:0]);
      repeat(3) @(negedge clk);end
  endtask
  task consume;
    begin @(negedge clk);take=1;@(negedge clk);take=0;
      if(ready) $fatal(1,"Consumed seed remained ready");end
  endtask
  initial begin
    #20;rst_n=1;
    word_in(0);if(ready) $fatal(1,"Zero seed was accepted");
    word_in(32'hffffffff);if(ready) $fatal(1,"All-ones seed was accepted");
    word_in(32'h01020304);
    if(!ready || data!==32'h01020304 || failed) $fatal(1,"Seed assembly failed");
    word_in(32'h55667788);
    if(!ready || data!==32'h01020304) $fatal(1,"Unconsumed seed was overwritten");
    consume;
    word_in(32'h01020304);if(ready) $fatal(1,"Previous seed was reused");
    word_in(32'ha1b2c3d4);
    if(!ready || data!==32'ha1b2c3d4) $fatal(1,"Next fresh seed failed");
    inject_fault=1;#1;if(ready || !failed) $fatal(1,"Source fault did not inhibit seed readiness");
    repeat(3) @(negedge clk);
    rst_n=0;inject_fault=0;repeat(3) @(negedge clk);rst_n=1;
    // Fault while a complete candidate is still being validated: flushing
    // must prevent a later cache publication, including after the fault drops.
    byte_in(8'h87);byte_in(8'h65);byte_in(8'h43);byte_in(8'h21);
    inject_fault=1;repeat(2) @(negedge clk);inject_fault=0;
    repeat(3) @(negedge clk);
    if(ready) $fatal(1,"A faulted in-flight candidate was published");
    rst_n=0;repeat(3) @(negedge clk);rst_n=1;
    for(n=0;n<8;n=n+1) word_in(0);
    if(!failed || ready) $fatal(1,"Repeated invalid seeds did not fail closed");
    $display("PASS: actual seed pool; complete words, immutable token, consume, zero/repeat rejection and faults");
    $finish;
  end
  initial begin #100000;$fatal(1,"Seed-pool watchdog expired");end
endmodule
