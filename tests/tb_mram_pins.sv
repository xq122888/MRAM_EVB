`timescale 1ns/1ps
// Independent pin contract: all addresses, including each loop's first address,
// use the same slots. No configuration/control signal is forced. Ideal clock
// and seed fixtures come from tb_top_timing.sv; this is not analogue sign-off.
module tb_mram_pins;
  reg clk=0,rst_n=0,sclk=0,cs_n=1,mosi=0,checking=0;
  wire miso,en,wn,gn,ub,lb;
  wire [21:0] address;
  wire [15:0] dq;
  reg [7:0] cfg[0:23],bytes[0:63],unused,checksum;
  integer period_cfg=10,length_cfg=4,mode_cfg=0,write_cfg=0,read_cfg=0,chip_cfg=8'h83;
  reg [21:0] base_cfg=0;
  integer case_no=0,started=0,completed=0,tick=0,slot,offset,phase;
  integer pin_checks=0,write_ends=0,expected_cycles,expected_words;
  integer p,w,r,variant,read_period,write_cycles,read_tick,tail_cycles;
  integer clock_no=0,launched=0,captured=0,compared=0,capture_total=0;
  integer sample_due[0:63];
  reg [21:0] sample_addr[0:63];
  reg [15:0] sample_expected[0:63];
  reg sample_now,compare_now;
  wire chip_output = !en && wn && !gn && (!ub || !lb);
  wire chip_output_hold;
  // Explicit digital fixture: retains output 10 ns after disabling. Read2's
  // requested +45 ns capture requires physical output hold after +40 ns.
  assign #(0,10) chip_output_hold=chip_output;
  reg previous_flg=0,previous_write=0;
  reg want_en,want_wn,want_gn,want_bn,read_phase;
  reg [15:0] want_data;
  always #2.5 clk=~clk;
  // Resolve real output-enable combinations, so writes with OE enabled cause
  // contention instead of being hidden by an internal read-phase condition.
  assign dq=chip_output_hold?16'h1234:16'hzzzz;
  top dut(.clkp(clk),.clkn(~clk),.rst_n(rst_n),.spi_sclk(sclk),
    .spi_cs_n(cs_n),.spi_mosi(mosi),.spi_miso(miso),.A(address),
    .DQ(dq),.EN(en),.WN(wn),.GN(gn),.UBN(ub),.LBN(lb));
  reg [42:0] expected_pad;
  always @(posedge clk) begin
    expected_pad={dut.pad_cmd_en,dut.pad_cmd_wn,dut.pad_cmd_gn,dut.pad_cmd_ubn,dut.pad_cmd_lbn,dut.pad_cmd_addr,dut.pad_cmd_dq_write};
    if(checking && rst_n && dut.flg && !dut.detail_stall && !dut.read_pipeline_flush) begin
      if(dut.period_event!==dut.period_match) $fatal(1,"Predicted period pulse diverged");
      if(dut.hold_before_two && !dut.count_restart &&
         (dut.count_wrap_cached!==dut.count_wrap_raw || dut.count_less_cached!==dut.addr_count_less))
        $fatal(1,"Cached count boundary was not ready at P-2");
    end
    clock_no=clock_no+1;
    compare_now=checking && rst_n && !dut.detail_stall && dut.read_compare_valid;
    sample_now=checking && rst_n && !dut.detail_stall && dut.read_sample_valid;
    if(sample_now) begin
      if(captured>=launched || sample_due[captured]!=clock_no)
        $fatal(1,"Wrong capture instant case=%0d capture=%0d clock=%0d expected=%0d",case_no,captured,clock_no,sample_due[captured]);
      if(dq!==16'h1234) $fatal(1,"Sampled invalid/contended read bus");
    end
    #0.2;
    if(sample_now) begin
      if(dut.dq_read_data!==16'h1234) $fatal(1,"IOB failed to capture DQ at requested edge");
      captured=captured+1;capture_total=capture_total+1;
    end
    if(compare_now) begin
      if(clock_no!=sample_due[compared]+1 ||
         dut.error_addr_snapshot!==sample_addr[compared] ||
         dut.error_expected_snapshot!==sample_expected[compared] ||
         dut.error_data_snapshot!==16'h1234)
        $fatal(1,"Comparison lost captured address/data case=%0d compare=%0d A=%h expectedA=%h data=%h expected=%h want=%h",case_no,compared,dut.error_addr_snapshot,sample_addr[compared],dut.error_data_snapshot,dut.error_expected_snapshot,sample_expected[compared]);
      compared=compared+1;
    end
    if(!rst_n || !checking) begin previous_flg=0;previous_write=0;end
    else begin
      if({en,wn,gn,ub,lb,address,dut.dq_write_data}!==expected_pad)
        $fatal(1,"IOB output did not follow the registered command");
      if(dut.addr_compare_count!==dut.addr_cnt ||
         dut.hold_release_count!==dut.addr_hold_cnt || dut.hold_sample_count!==dut.addr_hold_cnt)
        $fatal(1,"Replicated counters diverged");
      if(dut.pad_active) begin
        if(!previous_flg) begin tick=0;started=started+1;end
        else tick=tick+1;
        read_period=(read_cfg==1 && period_cfg<8)?8:period_cfg;
        tail_cycles=((read_cfg==1)?9:8)-read_period;
        if(tail_cycles<0)tail_cycles=0;
        write_cycles=(mode_cfg==1)?0:length_cfg*period_cfg;
        expected_cycles=write_cycles+((mode_cfg==0)?0:(length_cfg*read_period+tail_cycles));
        if(tick>=expected_cycles || dut.loop_idx!==started-1)
          $fatal(1,"Unexpected extra access case=%0d tick=%0d loop=%0d",case_no,tick,dut.loop_idx);
        read_phase=(mode_cfg==1 || (mode_cfg==2 && tick>=write_cycles));
        if(read_phase) begin
          read_tick=tick-write_cycles;
          offset=read_tick/read_period;
          if(offset>=length_cfg)offset=length_cfg-1;
          slot=read_tick-offset*read_period;
        end else begin slot=tick%period_cfg;offset=tick/period_cfg;end
        if(address!==base_cfg+offset)
          $fatal(1,"Wrong first/next address case=%0d loop=%0d tick=%0d got=%h expected=%h",case_no,dut.loop_idx,tick,address,base_cfg+offset);
        if(read_phase) begin
          want_wn=1;
          want_en=(read_cfg==0)?0:(slot==0 || slot>=read_period);
          want_gn=(read_cfg==0)?0:(slot==0 || slot>=read_period);
          want_bn=(read_cfg==0)?0:(slot==0 || slot>=read_period);
          if(chip_cfg==8'h80) want_bn=0;
        end else begin
          want_gn=1;
          case(write_cfg)
            0:begin want_en=!(slot>=1 && slot<period_cfg-3);
                    want_wn=!(slot<period_cfg-2);want_bn=want_wn;end
            1:begin want_en=!(slot<period_cfg-2);
                    want_wn=!(slot>=1 && slot<period_cfg-3);want_bn=want_en;end
            2:begin want_en=!(slot<period_cfg-2);
                    want_wn=want_en;want_bn=!(slot>=1 && slot<period_cfg-3);end
          endcase
          if(chip_cfg==8'h80) want_bn=0;
          want_data=(offset%2==0)?16'h5a5a:16'ha5a5;
          if(dq!==want_data)
            $fatal(1,"Unprepared/contended write data case=%0d loop=%0d tick=%0d A=%h DQ=%h expected=%h",case_no,dut.loop_idx,tick,address,dq,want_data);
        end
        if({en,wn,gn,ub,lb}!=={want_en,want_wn,want_gn,want_bn,want_bn})
          $fatal(1,"Pin order case=%0d mode=%0d write=%0d read=%0d period=%0d loop=%0d offset=%0d slot=%0d got CE/WE/OE/UB/LB=%b expected=%b",case_no,mode_cfg,write_cfg,read_cfg,period_cfg,dut.loop_idx,offset,slot,{en,wn,gn,ub,lb},{want_en,want_wn,want_gn,want_bn,want_bn});
        if(read_phase && slot==0) begin
          sample_due[launched]=clock_no+((read_cfg==1)?9:8);
          sample_addr[launched]=base_cfg+offset;
          sample_expected[launched]=(offset%2==0)?16'h5a5a:16'ha5a5;
          launched=launched+1;
        end
        if(read_phase && !dut.pad_read) $fatal(1,"Read bus direction lagged pin cycle");
        if(previous_write && !(!en && !wn && (!ub || !lb))) write_ends=write_ends+1;
        previous_write=(!en && !wn && (!ub || !lb));
        pin_checks=pin_checks+1;
      end else begin
        if(previous_flg) begin
          if(tick+1!=expected_cycles)
            $fatal(1,"Truncated loop case=%0d length=%0d got=%0d expected=%0d",case_no,length_cfg,tick+1,expected_cycles);
          completed=completed+1;
        end
        if({en,wn,gn,ub,lb}!==5'b11111)
          $fatal(1,"Idle interface was not released");
        previous_write=0;
      end
      previous_flg=dut.pad_active;
    end
  end
  task byte_io(input [7:0] value,output [7:0] result);
    integer b;
    begin
      for(b=7;b>=0;b=b-1) begin
        mosi=value[b];#31;sclk=1;#1;result[b]=miso;#30;sclk=0;
      end
    end
  endtask
  task run_case(input integer reset_first);
    integer i,j;
    begin
      checking=0;cs_n=1;sclk=0;
      if(reset_first) begin rst_n=0;#30;@(negedge clk);rst_n=1;end
      #100;started=0;completed=0;write_ends=0;launched=0;captured=0;compared=0;checking=1;
      for(i=0;i<24;i=i+1)cfg[i]=0;
      cfg[0]=8'h55;cfg[1]=chip_cfg;cfg[2]=mode_cfg;cfg[3]=3;
      cfg[4]=base_cfg[7:0];cfg[5]=base_cfg[15:8];cfg[6]=base_cfg[21:16];
      cfg[8]=length_cfg;cfg[12]=3;cfg[16]=period_cfg;cfg[17]=write_cfg;cfg[18]=read_cfg;
      checksum=0;for(i=1;i<=21;i=i+1)checksum=checksum+cfg[i];cfg[22]=checksum;cfg[23]=8'haa;
      cs_n=0;#60;for(i=0;i<24;i=i+1)byte_io(cfg[i],unused);#60;cs_n=1;
      for(j=0;j<3;j=j+1)begin
        // Completion can be announced before the final access has drained.
        // Poll only once the summary is eligible to start a fresh CS frame.
        wait(dut.u_spi_protocol.pending_test_complete && !dut.u_spi_protocol.test_busy);#60;
        cs_n=0;#60;for(i=0;i<64;i=i+1)byte_io(0,bytes[i]);#60;cs_n=1;#100;
        if(bytes[0]!==8'h55) $fatal(1,"Missing completion frame");
        if(mode_cfg==2)begin
          if(bytes[1]!==8'h11 || {bytes[6],bytes[5],bytes[4],bytes[3]}!==j)
            $fatal(1,"Bad write/read completion sequence");
        end else if(bytes[1]!==8'hff || {bytes[5],bytes[4],bytes[3],bytes[2]}!==j)
          $fatal(1,"Bad basic completion sequence");
      end
      expected_words=(mode_cfg==1)?0:3*length_cfg;
      if(started!=3 || completed!=3 || write_ends!=expected_words || (captured!=((mode_cfg==0)?0:3*length_cfg) || compared!=captured) || !dut.loop_done)
        $fatal(1,"Missing/duplicate loop or write case=%0d starts=%0d ends=%0d writes=%0d expected=%0d",case_no,started,completed,write_ends,expected_words);
      $display("PASS pins case %0d: mode=%0d write=%0d read=%0d period=%0d length=%0d base=%h chip=%h; all first/steady cycles, 3 loops",case_no,mode_cfg,write_cfg,read_cfg,period_cfg,length_cfg,base_cfg,chip_cfg);
      checking=0;case_no=case_no+1;
    end
  endtask
  initial begin
    for(p=0;p<2;p=p+1)begin
      period_cfg=(p==0)?7:10;
      for(variant=0;variant<4;variant=variant+1)begin
        length_cfg=(variant<2)?4:1;base_cfg=(variant%2==0)?0:22'h12000;
        mode_cfg=0;read_cfg=0;
        for(w=0;w<3;w=w+1)begin write_cfg=w;run_case(1);end
        mode_cfg=1;write_cfg=0;
        for(r=0;r<2;r=r+1)begin read_cfg=r;run_case(1);end
        mode_cfg=2;
        for(w=0;w<3;w=w+1)begin
          write_cfg=w;for(r=0;r<2;r=r+1)begin read_cfg=r;run_case(1);end
        end
      end
      chip_cfg=8'h80;mode_cfg=2;length_cfg=4;base_cfg=22'h12000;read_cfg=1;
      for(w=0;w<2;w=w+1)begin write_cfg=w;run_case(1);end
      chip_cfg=8'h83;
    end
    // Exercise the comparator's 8/9-cycle boundary and a long command period.
    mode_cfg=2;length_cfg=1;base_cfg=22'h12000;
    for(p=0;p<4;p=p+1)begin
      case(p)0:period_cfg=8;1:period_cfg=9;2:period_cfg=35;3:period_cfg=255;endcase
      for(variant=0;variant<2;variant=variant+1)begin
        length_cfg=(variant==0)?1:4;
        for(w=0;w<3;w=w+1)begin
          write_cfg=w;for(r=0;r<2;r=r+1)begin read_cfg=r;run_case(1);end
        end
      end
    end
    // Same-mode restart after a completed multi-loop test, with no board reset.
    mode_cfg=2;write_cfg=0;read_cfg=1;period_cfg=10;length_cfg=4;base_cfg=0;
    run_case(0);run_case(0);
    $display("PASS: %0d pin configurations, %0d cycle checks, %0d correctly paired captures; first address, every subsequent address, all loop starts, write/read turnarounds, OE direction and same-mode restart",case_no,pin_checks,capture_total);
    $finish;
  end
  initial begin #20000000;$fatal(1,"Pin regression watchdog");end
endmodule
