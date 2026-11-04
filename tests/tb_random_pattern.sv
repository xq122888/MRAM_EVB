`timescale 1ns/1ps
// Digital replay test. Writes are captured from actual A/DQ/WN pins. During
// the read pass an ideal bus supplies stored words with 40 ns address latency.
// CE/OE analogue behaviour and physical MRAM timing are not modelled.
module tb_random_pattern;
  reg clk=0,rst_n=0,sclk=0,cs_n=1,mosi=0,active=0;
  wire [21:0] address;
  wire [15:0] dq;
  wire en,wn;
  reg [15:0] memory[0:511],read_value=0;
  reg [31:0] vectors[0:511];
  reg [1023:0] vector_path;
  reg memory_changed=0;
  reg [7:0] cfg[0:23],bytes[0:63],unused,checksum;
  integer writes[0:1],details[0:1],seen[0:1][0:511];
  integer case_no,period_cfg,length_cfg,chip_cfg,detail_cfg,fault_cfg;
  integer summaries=0,acks=0,total_writes=0,read_checks=0,pauses=0,seed_wait_cycles=0;
  integer seeds_taken=0,seed_base=0;
  reg [31:0] granted_seed;
  integer i,j,idx,loop_no,report_loop,report_index,polls,before_ack;
  reg prior_stall=0;
  reg [95:0] prior_random;
  reg [15:0] want,comparison_word;
  reg [21:0] comparison_address;
  localparam [21:0] BASE=22'h12000;
  always #2.5 clk=~clk;
  top dut(.clkp(clk),.clkn(~clk),.rst_n(rst_n),.spi_sclk(sclk),
    .spi_cs_n(cs_n),.spi_mosi(mosi),.spi_miso(miso),.A(address),
    .DQ(dq),.EN(en),.WN(wn));
  assign dq=(dut.rd_en_d2 && dut.flg)?read_value:16'hzzzz;
  function [15:0] golden(input integer round_no,input integer offset);
    reg [31:0] value;
    begin
      value=vectors[round_no+offset+seed_base];
      golden=(chip_cfg==8'h80)?{value[7:0],value[7:0]}:value[15:0];
    end
  endfunction
  always @(posedge wn) begin
    if(active && rst_n && !en && !dut.rd_en_d2 && address>=BASE && address<BASE+length_cfg) begin
      idx=address-BASE;loop_no=dut.loop_idx;
      if(loop_no>1 || seen[loop_no][idx]!=0) $fatal(1,"Duplicate/random write loop=%0d addr=%h data=%h count=%0d h=%0d rd=%b/%b/%b finish=%b keep=%b",loop_no,address,dq,dut.addr_cnt,dut.addr_hold_cnt,dut.rd_en,dut.rd_en_d,dut.rd_en_d2,dut.loop_finish,dut.keep);
      want=golden(loop_no,idx);
      if(dq!==want) $fatal(1,"Random write loop=%0d offset=%0d got=%h expected=%h",loop_no,idx,dq,want);
      memory[idx]=dq;seen[loop_no][idx]=1;writes[loop_no]=writes[loop_no]+1;
      total_writes=total_writes+1;memory_changed=~memory_changed;
    end
  end
  always @(address or memory_changed) begin
    if(address>=BASE && address<BASE+length_cfg)
      read_value <= #40 (memory[address-BASE] ^ ((fault_cfg && address==BASE+2)?16'd1:16'd0));
    else read_value <= #40 16'd0;
  end
  always @(posedge clk) begin
    if(active && rst_n) begin
      if(dut.send_frame_ack) acks=acks+1;
      if(dut.random_seed_wait) begin
        seed_wait_cycles=seed_wait_cycles+1;
        if(dut.spi_start_test) $fatal(1,"Started while seed request remained pending");
      end
      if(dut.spi_start_test) begin
        if(!dut.trng_seed_ready || dut.trng_seed_fault || dut.trng_seed_data==0)
          $fatal(1,"Random start lacked a fresh nonzero seed");
        granted_seed=dut.trng_seed_data;seeds_taken=seeds_taken+1;
        if(granted_seed!==vectors[seed_base]) $fatal(1,"Test reused the previous fixture seed");
      end
      if(!dut.detail_stall && dut.flg && dut.rd_en_d &&
         !dut.spi_start_test && dut.start_d1==dut.start_d2 && !dut.next_loop_start_d1) begin
        comparison_address=0;
        if(dut.addr_hold_cnt==dut.vio_t_AVQV-dut.vio_t_AVAV && dut.addr_d!=dut.vio_addr_ini) begin
          comparison_address=dut.dout_ref_addr;comparison_word=dut.dout_ref;
        end else if(dut.addr_hold_cnt==dut.vio_t_AVQV) begin
          comparison_address=dut.addr_d;comparison_word=dut.dout_d1;
        end
        if(comparison_address>=BASE && comparison_address<BASE+length_cfg) begin
          if(comparison_word!==golden(dut.loop_idx,comparison_address-BASE))
            $fatal(1,"Read expected word failed to replay written sequence addr=%h got=%h",comparison_address,comparison_word);
          read_checks=read_checks+1;
        end
      end
      #1;
      if(dut.start_d1 && dut.random_test_seed!==granted_seed)
        $fatal(1,"Start seed was not latched atomically");
      if(prior_stall && dut.detail_stall && {dut.random_seed,dut.random_state,dut.dout,16'd0}!==prior_random)
        $fatal(1,"PRNG advanced while detailed error was pending");
      prior_stall=dut.detail_stall;
      prior_random={dut.random_seed,dut.random_state,dut.dout,16'd0};
      if(dut.detail_stall) pauses=pauses+1;
    end else prior_stall=0;
  end
  task byte_io(input [7:0] value,output [7:0] result);
    integer b;
    begin
      for(b=7;b>=0;b=b-1) begin mosi=value[b];#111;sclk=1;#1;result[b]=miso;#110;sclk=0;end
    end
  endtask
  task configure;
    begin
      for(i=0;i<24;i=i+1) cfg[i]=0;
      cfg[0]=8'h55;cfg[1]=chip_cfg;cfg[2]=2;cfg[3]=9;
      cfg[4]=BASE[7:0];cfg[5]=BASE[15:8];cfg[6]=BASE[21:16];
      cfg[8]=length_cfg[7:0];cfg[9]=length_cfg[15:8];cfg[12]=2;
      cfg[16]=period_cfg;cfg[17]=1;cfg[18]=1;cfg[19]=detail_cfg;
      checksum=0;for(i=1;i<=21;i=i+1) checksum=checksum+cfg[i];
      cfg[22]=checksum;cfg[23]=8'haa;
      cs_n=0;#100;for(i=0;i<24;i=i+1) byte_io(cfg[i],unused);#100;cs_n=1;#200;
    end
  endtask
  task poll;
    begin
      cs_n=0;#100;for(i=0;i<64;i=i+1) byte_io(0,bytes[i]);#100;cs_n=1;#200;
    end
  endtask
  initial begin
    if(!$value$plusargs("vectors=%s",vector_path)) $fatal(1,"Missing Python reference vectors");
    $readmemh(vector_path,vectors);
    for(case_no=0;case_no<10;case_no=case_no+1) begin
      active=0;cs_n=1;sclk=0;
      if(case_no!=8) begin rst_n=0;#30;@(negedge clk);rst_n=1;end
      seed_base=(case_no==8)?1:0;
      period_cfg=(case_no==1 || case_no==6 || case_no==8)?7:((case_no==2)?13:10);
      case(case_no) 0:length_cfg=17;1:length_cfg=5;2:length_cfg=4;3:length_cfg=1;4:length_cfg=300;default:length_cfg=9;endcase
      chip_cfg=(case_no==7)?8'h80:8'h83;
      detail_cfg=(case_no==5 || case_no==6 || case_no==8 || case_no==9);fault_cfg=detail_cfg;
      for(i=0;i<512;i=i+1) begin memory[i]=0;seen[0][i]=0;seen[1][i]=0;end
      writes[0]=0;writes[1]=0;details[0]=0;details[1]=0;
      summaries=0;acks=0;polls=0;pauses=0;read_checks=0;
      active=1;#100;configure;
      if(case_no==9) begin
        // Replace an active test with an unsent error. Force entropy unavailable
        // while the new command arrives, then grant the next fresh fixture seed.
        wait(dut.u_spi_protocol.detail_pending);active=0;
        force dut.u_seed_rng.seed_ready=1'b0;
        fault_cfg=0;configure;
        if(!dut.random_seed_wait || dut.flg || dut.spi_start_test)
          $fatal(1,"Waiting replacement did not stop the old memory engine");
        poll;for(i=0;i<64;i=i+1) if(bytes[i]!==0) $fatal(1,"Old report leaked during seed wait");
        for(i=0;i<512;i=i+1) begin memory[i]=0;seen[0][i]=0;seen[1][i]=0;end
        writes[0]=0;writes[1]=0;details[0]=0;details[1]=0;
        summaries=0;acks=0;polls=0;pauses=0;read_checks=0;seed_base=1;
        active=1;release dut.u_seed_rng.seed_ready;
      end
      while(summaries<2) begin
        wait(dut.u_spi_protocol.detail_pending || dut.u_spi_protocol.pending_test_complete);
        #200;before_ack=acks;poll;polls=polls+1;
        if(polls>40) $fatal(1,"Random test stalled");
        if(bytes[0]!=0) begin
          report_loop={bytes[6],bytes[5],bytes[4],bytes[3]};
          if(report_loop>1 || bytes[0]!==8'h55 || bytes[2]!==8'hff) $fatal(1,"Bad random report header");
          if(bytes[1]==8'h19) begin
            report_index={bytes[15],bytes[14],bytes[13],bytes[12]};
            if(!fault_cfg || report_index!=1 || details[report_loop]!=0 ||
               {bytes[19],bytes[18],bytes[17],bytes[16]}!=={10'd0,BASE+22'd2} ||
               {bytes[23],bytes[22]}!==golden(report_loop,2) ||
               {bytes[21],bytes[20]}!==(golden(report_loop,2)^16'd1) || acks!=before_ack)
              $fatal(1,"Random detail mismatch loop=%0d index=%0d",report_loop,report_index);
            details[report_loop]=details[report_loop]+1;
          end else if(bytes[1]==8'h11) begin
            if(report_loop!=summaries || {bytes[15],bytes[14],bytes[13],bytes[12]}!==fault_cfg ||
               bytes[11]!==fault_cfg || acks!=before_ack+1 || details[report_loop]!=fault_cfg)
              $fatal(1,"Random summary mismatch loop=%0d count=%0d",report_loop,{bytes[15],bytes[14],bytes[13],bytes[12]});
            if(writes[report_loop]!=length_cfg) $fatal(1,"Not all random addresses written %0d/%0d",writes[report_loop],length_cfg);
            summaries=summaries+1;
          end else $fatal(1,"Unknown random frame");
        end
      end
      if(case_no==0 && seed_wait_cycles==0) $fatal(1,"Unready seed waiting was not exercised");
      if(read_checks==0 || (fault_cfg && pauses==0)) $fatal(1,"Random coverage missing");
      $display("PASS random case %0d: period=%0d length=%0d chip=%h detail=%0d writes=%0d/%0d read checks=%0d",case_no,period_cfg,length_cfg,chip_cfg,detail_cfg,writes[0],writes[1],read_checks);
      active=0;
    end
    if(seeds_taken!=11) $fatal(1,"Seed consumed more than once per test");
    $display("PASS: %0d pin-observed random writes, reproducible readback, odd/even lengths, x8/x16, >256 addresses, faults, pauses and same-mode restart",total_writes);
    $finish;
  end
  initial begin #15000000;$fatal(1,"Random pattern watchdog expired");end
endmodule
