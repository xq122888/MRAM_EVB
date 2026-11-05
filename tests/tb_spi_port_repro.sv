`timescale 1ns/1ps
// Port-only board-symptom regression: no internal forces or implementation
// signal names. Can also run against Vivado's post-implementation netlist.
// The digital MRAM has 35 ns address latency and an explicit 10 ns output hold.
module tb_spi_port_repro;
  reg clk=0,rst_n=0,sclk=0,cs_n=1,mosi=0,checking=0;
  wire miso,en,wn,gn,ub,lb;
  wire [21:0] address;
  wire [15:0] dq;
  reg [15:0] memory[0:3],read_value=0;
  reg memory_changed=0;
  reg [7:0] cfg[0:23],bytes[0:63],unused,checksum;
  integer pattern_cfg=1,read_pass=0,write_count=0,details=0,polls=0;
  integer pat,last_pattern=8,all_writes=0,all_summaries=0,i,idx,expected_writes;
  integer pin_log;
  reg summary_seen=0;
  realtime window_begin,wn_low_time;
  wire chip_output=!en && wn && !gn && (!ub || !lb);
  wire chip_output_hold;
  wire write_window=!en && !wn && (!ub || !lb);
  assign #(0,10) chip_output_hold=chip_output;
  assign dq=chip_output_hold?read_value:16'hzzzz;
  always #2.5 clk=~clk;
  top dut(.clkp(clk),.clkn(~clk),.rst_n(rst_n),.spi_sclk(sclk),.spi_cs_n(cs_n),
    .spi_mosi(mosi),.spi_miso(miso),.A(address),.DQ(dq),
    .EN(en),.WN(wn),.GN(gn),.UBN(ub),.LBN(lb));
  function [15:0] golden(input integer pat,input integer offset,input integer background);
    case(pat)
      1:golden=background?16'hffff:16'h0000;
      2:golden=background?16'h0000:16'hffff;
      3:golden=offset%2?16'haaaa:16'h5555;
      4:golden=offset%2?16'h5555:16'haaaa;
      5:golden=offset%2?16'hffff:16'h0000;
      6:golden=offset%2?16'h0000:16'hffff;
      7:golden=offset;8:golden=16'hffff-offset;
      default:golden=16'hxxxx;
    endcase
  endfunction
  always @(negedge wn) if(checking) wn_low_time=$realtime;
  always @(posedge write_window) if(checking) begin
    window_begin=$realtime;
    if(($realtime-wn_low_time)<4.99 || ($realtime-wn_low_time)>5.01 || gn!==1)
      $fatal(1,"CEN write setup invalid pattern=%0d address=%h",pattern_cfg,address);
  end
  always @(negedge write_window) if(checking && rst_n) begin
    idx=write_count%4;
    if(address!==idx || write_count>=expected_writes || gn!==1)
      $fatal(1,"Write address/count/order pattern=%0d write=%0d A=%h",pattern_cfg,write_count,address);
    if(($realtime-window_begin)<29.99 || ($realtime-window_begin)>30.01)
      $fatal(1,"CEN pulse width is not 30 ns for 50 ns cycle");
    if((^dq)===1'bx) $fatal(1,"Undriven/contended write DQ pattern=%0d A=%h",pattern_cfg,address);
    if(pattern_cfg!=9 && dq!==golden(pattern_cfg,idx,write_count/4))
      $fatal(1,"Write data mismatch pattern=%0d A=%h got=%h expected=%h",pattern_cfg,address,dq,golden(pattern_cfg,idx,write_count/4));
    memory[idx]=dq;memory_changed=~memory_changed;
    write_count=write_count+1;all_writes=all_writes+1;
  end
  always @(negedge gn) if(checking && rst_n) read_pass=read_pass+1;
  always @(address or memory_changed or read_pass) begin
    if(address<4) begin
      // Reproduce the user's single first-background detail: FFFF vs 0000
      // for pattern 1, and the inverse for pattern 2. The test must still finish.
      read_value <= #35 (memory[address] ^ ((pattern_cfg<=2 && read_pass==1 && address==0)?16'hffff:16'h0000));
    end else read_value <= #35 16'hdead;
  end
  task byte_io(input [7:0] value,output [7:0] result);
    integer b;
    begin for(b=7;b>=0;b=b-1)begin mosi=value[b];#111;sclk=1;#1;result[b]=miso;#110;sclk=0;end end
  endtask
  task configure;
    begin
      for(i=0;i<24;i=i+1)cfg[i]=0;
      cfg[0]=8'h55;cfg[1]=8'h83;cfg[2]=2;cfg[3]=pattern_cfg;
      cfg[8]=4;cfg[12]=1;cfg[16]=10;cfg[17]=0;cfg[18]=0;cfg[19]=1;
      checksum=0;for(i=1;i<=21;i=i+1)checksum=checksum+cfg[i];cfg[22]=checksum;cfg[23]=8'haa;
      cs_n=0;#100;for(i=0;i<24;i=i+1)byte_io(cfg[i],unused);#100;cs_n=1;#200;
    end
  endtask
  task poll;
    begin
      // Do not wait for an internal "finished" flag. Poll through SPI exactly
      // as a host would, while the multi-pass test may still be running.
      cs_n=0;#100;for(i=0;i<64;i=i+1)byte_io(0,bytes[i]);#100;cs_n=1;#200;
    end
  endtask
  always @(en or wn or gn or ub or lb or address or dq) if(checking && pin_log)
    $fwrite(pin_log,"%0t,%0d,%h,%h,%b,%b,%b,%b,%b\n",$realtime,pattern_cfg,address,dq,en,wn,gn,ub,lb);
  task run_pattern(input integer pat);
    begin
      checking=0;pattern_cfg=pat;read_pass=0;write_count=0;details=0;polls=0;summary_seen=0;
      expected_writes=(pat<=2)?8:4;
      checking=1;configure;
      while(!summary_seen && polls<12) begin
        poll;polls=polls+1;
        if(bytes[0]==0)begin
          for(i=0;i<64;i=i+1)if(bytes[i]!==0)$fatal(1,"Partial idle report");
        end else if(bytes[0]!==8'h55 || bytes[2]!==8'hff ||
                    {bytes[6],bytes[5],bytes[4],bytes[3]}!==0 ||
                    {bytes[10],bytes[9],bytes[8],bytes[7]}!==4)
          $fatal(1,"Wrong report header pattern=%0d",pat);
        else if(bytes[1]==8'h19) begin
          if(pat>2 || details!=0 || {bytes[15],bytes[14],bytes[13],bytes[12]}!==1 ||
             {bytes[19],bytes[18],bytes[17],bytes[16]}!==0 || bytes[24]!==8'haa ||
             {bytes[23],bytes[22]}!==golden(pat,0,0) ||
             {bytes[21],bytes[20]}!==~golden(pat,0,0))
            $fatal(1,"Unexpected error detail pattern=%0d",pat);
          details=details+1;
        end else if(bytes[1]==8'h11)begin
          if(bytes[16]!==8'haa || {bytes[15],bytes[14],bytes[13],bytes[12]}!==((pat<=2)?1:0) ||
             bytes[11]!==((pat<=2)?1:0) || details!=((pat<=2)?1:0))
            $fatal(1,"Wrong final summary pattern=%0d",pat);
          summary_seen=1;
        end else $fatal(1,"Unexpected report type %h",bytes[1]);
      end
      if(!summary_seen || write_count!=expected_writes || read_pass!=((pat<=2)?2:1))
        $fatal(1,"Timeout/incomplete pattern=%0d writes=%0d/%0d read-passes=%0d polls=%0d CE/WE/OE=%b%b%b",pat,write_count,expected_writes,read_pass,polls,en,wn,gn);
      #500;checking=0;all_summaries=all_summaries+1;
      $display("PASS port pattern %0d: base=0 N=4 CEN/Read1 50ns writes=%0d read-passes=%0d details=%0d summary=1",pat,write_count,read_pass,details);$fflush();
    end
  endtask
  initial begin
    pin_log=$fopen("spi_port_repro_pins.csv","w");
    if(!pin_log)$fatal(1,"Cannot create pin trace");
    $fwrite(pin_log,"time_ps,pattern,address,dq,cen_n,wen_n,oen_n,ubn,lbn\n");
    memory[0]=16'hd849;memory[1]=16'h5555;memory[2]=16'haaaa;memory[3]=16'h5555;
    #100;rst_n=1;#10000; // Also allows the real MMCM to lock in Vivado simulation.
    if($test$plusargs("with_random"))last_pattern=9;
    for(pat=1;pat<=last_pattern;pat=pat+1)run_pattern(pat);
    if(last_pattern==9)begin
      // Completed cross-type restarts in both directions, without board reset.
      run_pattern(1);run_pattern(2);run_pattern(9);run_pattern(3);
    end
    $display("PASS port-only reproduction: %0d patterns, %0d writes, %0d summaries; no reset between commands, immediate SPI polling, first-background error retained",last_pattern,all_writes,all_summaries);
    $fclose(pin_log);$finish;
  end
  initial begin #10000000;$fatal(1,"Port reproduction watchdog expired pattern=%0d writes=%0d",pattern_cfg,write_count);end
endmodule
