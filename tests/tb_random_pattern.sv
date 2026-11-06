`timescale 1ns/1ps
// Digital replay test. Writes are captured from actual A/DQ/control pins. During
// the read pass an ideal bus supplies stored words with 35 ns address latency (5 ns before Read1 capture).
// CE/OE analogue behaviour and physical MRAM timing are not modelled.
module tb_random_pattern;
  reg clk=0,rst_n=0,sclk=0,cs_n=1,mosi=0,active=0;
  wire [21:0] address;
  wire [15:0] dq;
  wire en,wn,gn,ubn,lbn;
  localparam MAX_WORDS=65537, LEGACY_CASES=10, BOUNDARY_CASES=48, PATTERN_CASES=112, ROLLING_CASES=6, REPRO_CASES=6;
  localparam CASES=LEGACY_CASES+BOUNDARY_CASES+PATTERN_CASES+ROLLING_CASES+REPRO_CASES;
  reg [15:0] memory[0:MAX_WORDS-1],read_value=0;
  reg [31:0] vectors[0:32767];
  reg [1023:0] vector_path;
  reg memory_changed=0;
  reg [7:0] cfg[0:23],bytes[0:63],unused,checksum;
  integer reads[0:2],writes[0:2],details[0:2],seen[0:2][0:MAX_WORDS-1];
  integer first_case=0,last_case=CASES,expected_seeds;
  integer case_no,period_cfg,length_cfg,chip_cfg,detail_cfg,fault_cfg;
  integer pattern_cfg,write_cfg,read_cfg,boundary_no,loops_cfg;
  integer summaries=0,acks=0,total_writes=0,read_checks=0,pauses=0,seed_wait_cycles=0;
  integer seeds_taken=0,seed_base=0;
  reg [31:0] granted_seed;
  integer i,j,idx,loop_no,report_loop,report_index,polls,before_ack;
  reg prior_stall=0;
  integer pin_tick=0,pin_write_cycles,pin_read_period,pin_read_tick;
  integer pin_offset,pin_slot,pin_tail,pin_total,pin_checks=0;
  reg prior_pad_active=0,pin_read,expect_en,expect_wn,expect_gn,expect_bn;
  reg [95:0] prior_random;
  reg [15:0] want,comparison_word;
  reg [21:0] comparison_address;
  reg [21:0] base_addr=22'h12000;
  always #2.5 clk=~clk;
  top dut(.clkp(clk),.clkn(~clk),.rst_n(rst_n),.spi_sclk(sclk),
    .spi_cs_n(cs_n),.spi_mosi(mosi),.spi_miso(miso),.A(address),
    .DQ(dq),.EN(en),.WN(wn),.GN(gn),.UBN(ubn),.LBN(lbn));
  assign dq=(dut.pad_read && dut.pad_active)?read_value:16'hzzzz;
  function [15:0] golden(input integer round_no,input integer offset);
    reg [31:0] value;
    begin
      case(pattern_cfg)
        1: value=0;
        2: value=16'hffff;
        3: value=offset%2?16'haaaa:16'h5555;
        4: value=offset%2?16'h5555:16'haaaa;
        5: value=offset%2?16'hffff:16'h0000;
        6: value=offset%2?16'h0000:16'hffff;
        7: value=round_no+offset;
        8: value=16'hffff-round_no-offset;
        default: value=vectors[round_no+offset+seed_base];
      endcase
      golden=(chip_cfg==8'h80)?{value[7:0],value[7:0]}:value[15:0];
    end
  endfunction
  // Store on the first terminating edge of CE/WE/byte enables, covering
  // CEN, WEN and UBN/LBN writes through the external pins.
  wire write_window = !en && !wn && (!ubn || !lbn);
  always @(negedge write_window) begin
    if(active && rst_n && !dut.pad_read && address>=base_addr && address<base_addr+length_cfg) begin
      idx=address-base_addr;loop_no=dut.loop_idx;
      if(loop_no>=loops_cfg || seen[loop_no][idx]!=0) $fatal(1,"Duplicate/random write loop=%0d addr=%h data=%h count=%0d h=%0d rd=%b/%b/%b finish=%b keep=%b",loop_no,address,dq,dut.addr_cnt,dut.addr_hold_cnt,dut.rd_en,dut.rd_en_d,dut.rd_en_d2,dut.loop_finish,dut.keep);
      if(idx!=writes[loop_no]) $fatal(1,"Write address order failed loop=%0d offset=%0d",loop_no,idx);
      want=golden(loop_no,idx);
      if(dq!==want) $fatal(1,"Random write loop=%0d offset=%0d got=%h expected=%h",loop_no,idx,dq,want);
      memory[idx]=dq;seen[loop_no][idx]=1;writes[loop_no]=writes[loop_no]+1;
      total_writes=total_writes+1;memory_changed=~memory_changed;
    end
  end
  always @(address or memory_changed) begin
    if(address>=base_addr && address<base_addr+length_cfg)
      read_value <= #35 (memory[address-base_addr] ^ ((fault_cfg && address==base_addr+2)?16'd1:16'd0));
    else read_value <= #35 16'd0;
  end
  always @(posedge clk) begin
    if(active && rst_n) begin
      if(dut.spi_detail_stall || (dut.detail_stall && !dut.random_seed_wait))
        $fatal(1,"Logging paused the random-data engine");
      if(dut.addr_compare_count!==dut.addr_cnt) $fatal(1,"Random address replica diverged");
      if(dut.send_frame_ack) acks=acks+1;
      if(dut.random_seed_wait) begin
        seed_wait_cycles=seed_wait_cycles+1;
        if(dut.spi_start_test) $fatal(1,"Started while seed request remained pending");
      end
      if(dut.spi_start_test && pattern_cfg==9) begin
        if(!dut.trng_seed_ready || dut.trng_seed_fault || dut.trng_seed_data==0)
          $fatal(1,"Random start lacked a fresh nonzero seed");
        granted_seed=dut.trng_seed_data;seeds_taken=seeds_taken+1;
        if(granted_seed!==vectors[seed_base]) $fatal(1,"Test reused the previous fixture seed");
      end
      if(!dut.detail_stall && !dut.read_pipeline_flush && dut.read_sample_valid) begin
        comparison_address=dut.read_due_0?dut.read_address_0:dut.read_address_1;
        comparison_word=dut.read_due_0?dut.read_expected_0:dut.read_expected_1;
        if(comparison_address>=base_addr && comparison_address<base_addr+length_cfg) begin
          if(dut.loop_idx>=loops_cfg || comparison_address-base_addr!=reads[dut.loop_idx])
            $fatal(1,"Read address order failed loop=%0d addr=%h",dut.loop_idx,comparison_address);
          reads[dut.loop_idx]=reads[dut.loop_idx]+1;
          if(comparison_word!==golden(dut.loop_idx,comparison_address-base_addr))
            $fatal(1,"Read expected word failed to replay written sequence addr=%h got=%h",comparison_address,comparison_word);
          read_checks=read_checks+1;
        end else $fatal(1,"Read outside configured range addr=%h",comparison_address);
      end
      #1;
      // Independent physical-pin contract for EVERY pattern, including all
      // four alternating types. Do not classify write/read using pad_read:
      // derive the phase from elapsed clocks and the configured word count.
      if(dut.pad_active) begin
        pin_tick=prior_pad_active?pin_tick+1:0;
        pin_write_cycles=length_cfg*period_cfg;
        pin_read_period=(read_cfg==1 && period_cfg<8)?8:period_cfg;
        pin_tail=((read_cfg==1)?9:8)-pin_read_period;
        if(pin_tail<0)pin_tail=0;
        pin_total=pin_write_cycles+length_cfg*pin_read_period+pin_tail;
        pin_read=pin_tick>=pin_write_cycles;
        if(pin_read) begin
          pin_read_tick=pin_tick-pin_write_cycles;pin_offset=pin_read_tick/pin_read_period;
          if(pin_offset>=length_cfg)pin_offset=length_cfg-1;
          pin_slot=pin_read_tick-pin_offset*pin_read_period;
          expect_wn=1;expect_en=(read_cfg==0)?0:(pin_slot==0 || pin_slot>=pin_read_period);
          expect_gn=expect_en;expect_bn=expect_en;
        end else begin
          pin_offset=pin_tick/period_cfg;pin_slot=pin_tick%period_cfg;expect_gn=1;
          case(write_cfg)
            0:begin expect_en=!(pin_slot>=1 && pin_slot<period_cfg-3);
                    expect_wn=!(pin_slot<period_cfg-2);expect_bn=expect_wn;end
            1:begin expect_en=!(pin_slot<period_cfg-2);
                    expect_wn=!(pin_slot>=1 && pin_slot<period_cfg-3);expect_bn=expect_en;end
            2:begin expect_en=!(pin_slot<period_cfg-2);
                    expect_wn=expect_en;expect_bn=!(pin_slot>=1 && pin_slot<period_cfg-3);end
          endcase
        end
        if(chip_cfg==8'h80)expect_bn=0;
        if(pin_tick>=pin_total || address!==base_addr+pin_offset ||
           {en,wn,gn,ubn,lbn}!=={expect_en,expect_wn,expect_gn,expect_bn,expect_bn})
          $fatal(1,"Pin timing pattern=%0d loop=%0d tick=%0d offset=%0d slot=%0d got=%b expected=%b",
            pattern_cfg,dut.loop_idx,pin_tick,pin_offset,pin_slot,{en,wn,gn,ubn,lbn},
            {expect_en,expect_wn,expect_gn,expect_bn,expect_bn});
        pin_checks=pin_checks+1;
      end else if(prior_pad_active && pin_tick+1!=pin_total)
        $fatal(1,"Pattern %0d lost/stretched an access cycle",pattern_cfg);
      prior_pad_active=dut.pad_active;
      if(pattern_cfg==9 && dut.start_d1 && dut.random_test_seed!==granted_seed)
        $fatal(1,"Start seed was not latched atomically");
      if(prior_stall && dut.detail_stall && {dut.random_seed,dut.random_state,dut.dout,16'd0}!==prior_random)
        $fatal(1,"PRNG advanced while detailed error was pending");
      prior_stall=dut.detail_stall;
      prior_random={dut.random_seed,dut.random_state,dut.dout,16'd0};
      if(dut.detail_stall) pauses=pauses+1;
    end else begin prior_stall=0;prior_pad_active=0;end
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
      cfg[0]=8'h55;cfg[1]=chip_cfg;cfg[2]=2;cfg[3]=pattern_cfg;
      cfg[4]=base_addr[7:0];cfg[5]=base_addr[15:8];cfg[6]=base_addr[21:16];
      cfg[8]=length_cfg[7:0];cfg[9]=length_cfg[15:8];cfg[10]=length_cfg[23:16];cfg[12]=loops_cfg;
      cfg[16]=period_cfg;cfg[17]=write_cfg;cfg[18]=read_cfg;cfg[19]=detail_cfg;
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
    expected_seeds=LEGACY_CASES+BOUNDARY_CASES+REPRO_CASES+1;
    if($test$plusargs("legacy_only")) begin
      last_case=LEGACY_CASES;expected_seeds=LEGACY_CASES+1;
    end else if($test$plusargs("repro_only")) begin
      first_case=CASES-REPRO_CASES;expected_seeds=REPRO_CASES;
    end else if($test$plusargs("short_patterns_only")) begin
      first_case=LEGACY_CASES+BOUNDARY_CASES+16;
      last_case=LEGACY_CASES+BOUNDARY_CASES+PATTERN_CASES;expected_seeds=0;
    end else if($test$plusargs("patterns_only")) begin
      first_case=LEGACY_CASES+BOUNDARY_CASES;
      last_case=CASES-REPRO_CASES;expected_seeds=0;
    end else if($test$plusargs("rolling_only")) begin
      first_case=LEGACY_CASES+BOUNDARY_CASES+PATTERN_CASES;
      last_case=CASES-REPRO_CASES;expected_seeds=0;
    end
    for(case_no=first_case;case_no<last_case;case_no=case_no+1) begin
      active=0;cs_n=1;sclk=0;
      if(case_no!=8 && case_no!=LEGACY_CASES+BOUNDARY_CASES+PATTERN_CASES+3 &&
         case_no!=LEGACY_CASES+BOUNDARY_CASES+PATTERN_CASES+5) begin rst_n=0;#30;@(negedge clk);rst_n=1;end
      seed_base=(case_no==8)?1:0;
      period_cfg=(case_no==1 || case_no==6 || case_no==8)?7:((case_no==2)?13:10);
      case(case_no) 0:length_cfg=17;1:length_cfg=5;2:length_cfg=4;3:length_cfg=1;4:length_cfg=300;default:length_cfg=9;endcase
      base_addr=22'h12000;loops_cfg=2;pattern_cfg=9;write_cfg=1;read_cfg=(case_no==1 || case_no==6)?0:1;
      if(case_no>=LEGACY_CASES && case_no<LEGACY_CASES+BOUNDARY_CASES) begin
        boundary_no=case_no-LEGACY_CASES;
        // Eight lengths x three write modes x two read modes.
        case(boundary_no/6)
          0:length_cfg=511; 1:length_cfg=512;
          2:length_cfg=575; 3:length_cfg=576; 4:length_cfg=577;
          5:length_cfg=1024; 6:length_cfg=1025; 7:length_cfg=16385;
        endcase
        write_cfg=(boundary_no/2)%3;read_cfg=boundary_no%2;
        period_cfg=7;
      end else if(case_no<LEGACY_CASES+BOUNDARY_CASES+PATTERN_CASES && case_no>=LEGACY_CASES+BOUNDARY_CASES) begin
        boundary_no=case_no-LEGACY_CASES-BOUNDARY_CASES;
        period_cfg=7;
        if(boundary_no<16) begin
          pattern_cfg=1+boundary_no/2;read_cfg=boundary_no%2;
          length_cfg=read_cfg?1025:577;
        end else begin
          // Every fixed pattern: all 3 write x 2 read modes, lengths 1/5,
          // two loops and an odd nonzero base (phase is relative to base).
          boundary_no=boundary_no-16;
          pattern_cfg=1+boundary_no/12;
          write_cfg=(boundary_no/4)%3;read_cfg=(boundary_no/2)%2;
          length_cfg=(boundary_no%2)?5:1;base_addr=22'h12001;
        end
      end
      if(case_no>=LEGACY_CASES+BOUNDARY_CASES+PATTERN_CASES &&
         case_no<LEGACY_CASES+BOUNDARY_CASES+PATTERN_CASES+ROLLING_CASES) begin
        boundary_no=case_no-LEGACY_CASES-BOUNDARY_CASES-PATTERN_CASES;
        // Actual pin writes cross FFFF/0000, run three rounds, then exercise
        // same-mode command replacement after a completed nonzero loop.
        pattern_cfg=(boundary_no==1 || boundary_no>=4)?8:7;
        length_cfg=(boundary_no<2)?65537:((boundary_no==4)?1:5);
        loops_cfg=3;base_addr=22'h12001;period_cfg=7;
        write_cfg=(boundary_no<2)?1:((boundary_no%2)?2:0);
        read_cfg=boundary_no%2;
      end
      if(case_no>=LEGACY_CASES+BOUNDARY_CASES+PATTERN_CASES+ROLLING_CASES) begin
        // User's 2026-11-05 capture: base 0, length 0x250, one round,
        // 50 ns, random x16, with details; also cross-check the other modes.
        boundary_no=case_no-LEGACY_CASES-BOUNDARY_CASES-PATTERN_CASES-ROLLING_CASES;
        base_addr=0;loops_cfg=1;length_cfg=592;period_cfg=10;
        pattern_cfg=9;write_cfg=boundary_no/2;read_cfg=boundary_no%2;
      end
      chip_cfg=(case_no==7)?8'h80:8'h83;
      fault_cfg=(case_no==5 || case_no==6 || case_no==8 || case_no==9);
      detail_cfg=fault_cfg || case_no>=LEGACY_CASES+BOUNDARY_CASES+PATTERN_CASES+ROLLING_CASES;
      for(i=0;i<MAX_WORDS;i=i+1) begin memory[i]=0;seen[0][i]=0;seen[1][i]=0;seen[2][i]=0;end
      reads[0]=0;reads[1]=0;reads[2]=0;writes[0]=0;writes[1]=0;writes[2]=0;details[0]=0;details[1]=0;details[2]=0;
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
        for(i=0;i<MAX_WORDS;i=i+1) begin memory[i]=0;seen[0][i]=0;seen[1][i]=0;seen[2][i]=0;end
        reads[0]=0;reads[1]=0;reads[2]=0;writes[0]=0;writes[1]=0;writes[2]=0;details[0]=0;details[1]=0;details[2]=0;
        summaries=0;acks=0;polls=0;pauses=0;read_checks=0;seed_base=1;
        active=1;release dut.u_seed_rng.seed_ready;
      end
      while(summaries<loops_cfg) begin
        wait(dut.u_spi_protocol.detail_pending || dut.u_spi_protocol.pending_test_complete);
        #200;before_ack=acks;poll;polls=polls+1;
        if(polls>40) $fatal(1,"Random test stalled");
        if(bytes[0]!=0) begin
          report_loop={bytes[6],bytes[5],bytes[4],bytes[3]};
          if(report_loop>=loops_cfg || bytes[0]!==8'h55 || bytes[2]!==8'hff) $fatal(1,"Bad random report header");
          if(bytes[1]==8'h19) begin
            report_index={bytes[15],bytes[14],bytes[13],bytes[12]};
            if(!fault_cfg || report_index!=1 || details[report_loop]!=0 ||
               {bytes[19],bytes[18],bytes[17],bytes[16]}!=={10'd0,base_addr+22'd2} ||
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
      if(read_checks!=loops_cfg*length_cfg)
        $fatal(1,"Incomplete memory read coverage %0d/%0d",read_checks,loops_cfg*length_cfg);
      for(j=0;j<loops_cfg;j=j+1)
        if(reads[j]!=length_cfg || writes[j]!=length_cfg)
          $fatal(1,"Incomplete round %0d writes=%0d reads=%0d expected=%0d",j,writes[j],reads[j],length_cfg);
      $display("PASS memory case %0d: pattern=%0d write=%0d read=%0d period=%0d length=%0d chip=%h detail=%0d writes=%0d/%0d read checks=%0d",case_no,pattern_cfg,write_cfg,read_cfg,period_cfg,length_cfg,chip_cfg,detail_cfg,writes[0],writes[1],read_checks);
      $fflush();
      active=0;
    end
    if(seeds_taken!=expected_seeds) $fatal(1,"Seed consumed more than once per test");
    if(first_case==0 && last_case==CASES)
      $display("PASS: %0d memory cases, %0d pin-observed writes, reproducible readback, odd/even lengths, x8/x16, all write/read modes, 0x200/0x240/0x400/0x4000 boundaries, all patterns, faults without logging pauses, seed wait and same-mode restart",CASES,total_writes);
    else if($test$plusargs("repro_only"))
      $display("PASS: %0d user-configuration cases, %0d pin-observed writes; base 0, length 592, one round, 50 ns, random x16, details enabled, all write/read modes",REPRO_CASES,total_writes);
    else
      $display("PASS: %0d selected memory cases, %0d pin-observed writes; configured data sequence, read replay, reports and restarts",last_case-first_case,total_writes);
    $display("PASS: %0d independent A/CE/WE/OE/UB/LB pin-cycle checks across selected data patterns",pin_checks);
    $finish;
  end
  initial begin #100000000;$fatal(1,"Random pattern watchdog expired");end
endmodule
