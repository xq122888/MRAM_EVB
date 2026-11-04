`timescale 1ns/1ps
module tb_seed_start;
  reg clk=0,rst_n=0,sclk=0,cs_n=1,mosi=0,ready=0;
  wire miso,start,waiting;
  reg [7:0] cfg[0:23],checksum,unused;
  integer i,starts=0;
  always #2.5 clk=~clk;
  spi_protocol dut(.clk(clk),.rst_n(rst_n),.spi_sclk(sclk),.spi_cs_n(cs_n),
    .spi_mosi(mosi),.spi_miso(miso),.random_seed_ready(ready),
    .start_test(start),.start_waiting(waiting),.current_loop(32'd0),
    .test_busy(1'b0),.test_done(1'b0),.error_cnt(32'd0),.err_flag(1'b0),
    .error_addr(22'd0),.error_data(16'd0),.expected_data(16'd0),.test_complete(1'b0));
  always @(posedge clk) if(start) starts=starts+1;
  task byte_io(input [7:0] value);
    integer b;
    begin for(b=7;b>=0;b=b-1) begin mosi=value[b];#111;sclk=1;#111;sclk=0;end end
  endtask
  task configure(input [7:0] pattern,input bad);
    begin
      for(i=0;i<24;i=i+1) cfg[i]=0;
      cfg[0]=8'h55;cfg[1]=8'h83;cfg[2]=2;cfg[3]=pattern;
      cfg[8]=4;cfg[12]=2;cfg[16]=10;cfg[17]=1;cfg[18]=1;
      checksum=0;for(i=1;i<=21;i=i+1) checksum=checksum+cfg[i];
      cfg[22]=checksum^(bad?8'd1:8'd0);cfg[23]=8'haa;
      cs_n=0;#100;for(i=0;i<24;i=i+1) byte_io(cfg[i]);#100;cs_n=1;#200;
    end
  endtask
  task grant;
    begin @(negedge clk);ready=1;repeat(6) @(negedge clk);ready=0;end
  endtask
  initial begin
    #20;rst_n=1;#100;
    configure(9,0);if(starts!=0 || !waiting) $fatal(1,"Unready random test started");
    repeat(20) @(negedge clk);grant;
    if(starts!=1 || waiting) $fatal(1,"Fresh seed did not grant exactly one start");
    configure(9,0);if(!waiting) $fatal(1,"Second random request did not wait");
    configure(5,1);if(!waiting || dut.data_pattern!=9) $fatal(1,"Bad checksum replaced pending test");
    grant;if(starts!=2 || waiting) $fatal(1,"Retained pending request failed");
    configure(9,0);configure(5,0);
    if(starts!=3 || waiting) $fatal(1,"Non-random replacement waited for entropy");
    grant;if(starts!=3) $fatal(1,"Cancelled random request replayed");
    configure(9,0);cs_n=0;#100;byte_io(8'h55);byte_io(8'hff);byte_io(8'haa);#100;cs_n=1;#200;
    if(waiting) $fatal(1,"Stop did not cancel waiting start");
    grant;if(starts!=3) $fatal(1,"Stopped pending request replayed");
    $display("PASS: seed-gated SPI starts, one-shot grant, invalid config retention, valid replacement and stop");
    $finish;
  end
  initial begin #2000000;$fatal(1,"Seed-start watchdog expired");end
endmodule
