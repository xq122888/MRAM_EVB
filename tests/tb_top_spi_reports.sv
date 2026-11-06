`timescale 1ns/1ps
// End-to-end DIGITAL control/protocol test with ideal clock/TRNG models from
// tb_top_timing.sv and a constant-zero read bus. This is not an MRAM model.
module tb_top_spi_reports;
  reg clk=0,rst_n=0,sclk=0,cs_n=1,mosi=0;
  wire miso,en,wn,gn;
  wire [15:0] dq;
  reg [7:0] cfg[0:23];
  integer mode,n,b,seq_no,count,reports=0;
  reg [7:0] checksum,received,expected;
  always #2.5 clk=~clk;
  assign dq=(!en && wn && !gn)?16'd0:16'hzzzz;
  top dut(.clkp(clk),.clkn(~clk),.rst_n(rst_n),.spi_sclk(sclk),
    .spi_cs_n(cs_n),.spi_mosi(mosi),.spi_miso(miso),.DQ(dq),
    .EN(en),.WN(wn),.GN(gn));
  task byte_io(input [7:0] value, output [7:0] result);
    integer bit_no;
    begin
      for(bit_no=7;bit_no>=0;bit_no=bit_no-1) begin
        mosi=value[bit_no];#111;sclk=1;
        #1;result[bit_no]=miso;#110;sclk=0;
      end
    end
  endtask
  initial begin
    #30;rst_n=1;#200;
    for(mode=0;mode<3;mode=mode+1) begin
      count=(mode==0)?4:3;
      for(n=0;n<24;n=n+1) cfg[n]=0;
      cfg[0]=8'h55;cfg[1]=8'h83;cfg[2]=mode;cfg[3]=1;
      cfg[8]=4;cfg[12]=count;cfg[16]=7;
      // Write/read mode exercises unequal periods: invalid-write fallback 10,
      // configured read period 7 (Read2 clamps it to 8). Other modes retain normal write mode 1.
      cfg[17]=(mode==2)?3:1;cfg[18]=1;
      checksum=0;
      for(n=1;n<=21;n=n+1) checksum=checksum+cfg[n];
      cfg[22]=checksum;cfg[23]=8'haa;
      cs_n=0;#100;
      for(n=0;n<24;n=n+1) byte_io(cfg[n],received);
      #100;cs_n=1;#200;
      for(seq_no=0;seq_no<count;seq_no=seq_no+1) begin
        wait(dut.loop_finish===1'b1);
        #200;cs_n=0;#100;
        for(n=0;n<64;n=n+1) begin
          byte_io(0,received);expected=0;
          if(mode==2) begin
            case(n)
              0:expected=8'h55;1:expected=8'h11;2:expected=8'hff;
              3,4,5,6:expected=seq_no >> ((n-3)*8);
              7:expected=4;16:expected=8'haa;
            endcase
          end else begin
            case(n)
              0:expected=8'h55;1:expected=8'hff;
              2,3,4,5:expected=seq_no >> ((n-2)*8);
              6:expected=4;10:expected=8'haa;
            endcase
          end
          if(received!==expected)
            $fatal(1,"End-to-end mode=%d sequence=%d byte=%d got=%h expected=%h",mode,seq_no,n,received,expected);
        end
        #100;cs_n=1;#200;reports=reports+1;
      end
      if(dut.loop_done!==1'b1) $fatal(1,"Loop count did not terminate");
    end
    $display("PASS: %0d end-to-end top-level reports across modes 0/1/2; real SPI configuration and ACK-driven loop control",reports);
    $finish;
  end
  initial begin #5000000;$fatal(1,"End-to-end watchdog expired");end
endmodule
