`timescale 1ns/1ps
// Independent operation-list and pin-memory oracle. Production RO entropy,
// board delays and timing closure are not modelled by the ideal clock fixture.
module tb_data_patterns;
  reg clk=0,rst_n=0,sclk=0,cs_n=1,mosi=0,active=0;
  wire miso,en,wn,gn,ub,lb;
  wire [21:0] address;
  wire [15:0] dq;
  reg [15:0] memory[0:1023],read_value=0;
  reg memory_changed=0;
  integer pattern_cfg=1,mode_cfg=0,nwords=3,period_cfg=7,write_cfg=1,read_cfg=0;
  integer rounds=2,fault_cfg=0,detail_cfg=1,chip_cfg=8'h83;
  bit replace_cfg=0;
  reg [21:0] base_cfg=22'h12000;
  reg [7:0] cfg[0:23],bytes[0:63],unused,checksum;
  reg op_read[0:16383];
  reg [21:0] op_addr[0:16383];
  reg [15:0] op_word[0:16383];
  integer nops=0,op_pos=0,round_no=0,writes=0,reads=0,errors=0,details=0;
  integer all_writes=0,all_reads=0,all_details=0,cases=0,starts=0,acks=0;
  reg [21:0] physical_reads[0:16383];
  integer physical_launches=0,physical_captures=0;
  reg prior_read=0;
  reg [21:0] prior_address;
  reg [21:0] error_addr[0:8191];
  reg [15:0] error_actual[0:8191],error_expected[0:8191];
  integer i,j,p,m,l,f,r,idx,polls,frame_loop,frame_index,reported_errors;
  integer before_starts;
  integer finished_errors[0:3],finished_details[0:3];
  reg [15:0] got;
  wire chip_output = !en && wn && !gn && (!ub || !lb);
  wire chip_output_hold;
  assign #(0,10) chip_output_hold=chip_output;
  assign dq=chip_output_hold?read_value:16'hzzzz;
  wire write_window = !en && !wn && (!ub || !lb);
  always #2.5 clk=~clk;
  top dut(.clkp(clk),.clkn(~clk),.rst_n(rst_n),.spi_sclk(sclk),.spi_cs_n(cs_n),
    .spi_mosi(mosi),.spi_miso(miso),.A(address),.DQ(dq),
    .EN(en),.WN(wn),.GN(gn),.UBN(ub),.LBN(lb));
  defparam dut.u_spi_protocol.DETAIL_FIFO_ADDR_BITS=3;
  function [15:0] word_at(input integer pat,input integer off);
    case(pat)
      1:word_at=0;2:word_at=16'hffff;
      3:word_at=off%2?16'haaaa:16'h5555;
      4:word_at=off%2?16'h5555:16'haaaa;
      5:word_at=off%2?16'hffff:16'h0000;
      6:word_at=off%2?16'h0000:16'hffff;
      7:word_at=off;8:word_at=16'hffff-off;
      default:word_at=0;
    endcase
  endfunction
  always @(address or memory_changed) begin
    if(address>=base_cfg && address<base_cfg+nwords)
      read_value <= #35 (memory[address-base_cfg] ^ ((fault_cfg==2 || (fault_cfg==1 && address==base_cfg))?16'd1:16'd0));
    else read_value <= #35 16'hdead;
  end
  task observe(input bit is_read,input [21:0] addr,input [15:0] actual);
    begin
      if(op_pos>=nops || is_read!==op_read[op_pos] || addr!==op_addr[op_pos])
        $fatal(1,"Operation order case=%0d pattern=%0d mode=%0d pos=%0d/%0d got R=%b A=%h expected R=%b A=%h phase=%0d index=%0d",cases,pattern_cfg,mode_cfg,op_pos,nops,is_read,addr,op_read[op_pos],op_addr[op_pos],dut.u_algorithm.phase,dut.addr_cnt);
      if(is_read) begin
        reads=reads+1;all_reads=all_reads+1;
        if(actual!==(op_word[op_pos] ^ ((fault_cfg==2 || (fault_cfg==1 && addr==base_cfg))?16'd1:16'd0)))
          $fatal(1,"Memory read incorrect case=%0d pos=%0d addr=%h got=%h expected=%h",cases,op_pos,addr,actual,op_word[op_pos]);
        if(actual!==op_word[op_pos]) begin
          error_addr[errors]=addr;error_actual[errors]=actual;error_expected[errors]=op_word[op_pos];errors=errors+1;
        end
      end else begin
        if(actual!==op_word[op_pos]) $fatal(1,"Wrong written word case=%0d pos=%0d addr=%h got=%h expected=%h",cases,op_pos,addr,actual,op_word[op_pos]);
        writes=writes+1;all_writes=all_writes+1;
      end
      op_pos=op_pos+1;
    end
  endtask
  always @(negedge write_window) if(active && rst_n) begin
    observe(0,address,dq);
    if(gn!==1) $fatal(1,"OE enabled during write");
    memory[address-base_cfg]=dq;memory_changed=~memory_changed;
  end
  always @(negedge clk) begin
    if(active && rst_n && dut.pad_active && dut.pad_read) begin
      if(!prior_read || address!==prior_address) begin
        physical_reads[physical_launches]=address;physical_launches=physical_launches+1;
      end
      prior_read=1;prior_address=address;
    end else prior_read=0;
  end
  // Independent per-access external-pin timing, including every algorithm
  // restart and read/write turnaround (no forcing of controller state).
  reg phy_prev=0,phy_read_prev=0;
  reg [21:0] phy_address_prev;
  integer phy_slot=0,phy_period,pin_checks=0;
  reg want_en,want_wn,want_gn,want_bn;
  always @(posedge clk) begin
    #0.2;
    if(active && rst_n && dut.pad_active) begin
      if(!phy_prev || address!==phy_address_prev || dut.pad_read!==phy_read_prev) phy_slot=0;
      else phy_slot=phy_slot+1;
      phy_period=(dut.pad_read && read_cfg==1 && period_cfg<8)?8:period_cfg;
      if(dut.pad_read) begin
        want_wn=1;want_en=(read_cfg==0)?0:!(phy_slot>=1 && phy_slot<phy_period);
        want_gn=want_en;want_bn=want_en;
      end else begin
        want_gn=1;
        case(write_cfg)
          0:begin want_en=!(phy_slot>=1 && phy_slot<phy_period-3);want_wn=!(phy_slot<phy_period-2);want_bn=want_wn;end
          1:begin want_en=!(phy_slot<phy_period-2);want_wn=!(phy_slot>=1 && phy_slot<phy_period-3);want_bn=want_en;end
          2:begin want_en=!(phy_slot<phy_period-2);want_wn=want_en;want_bn=!(phy_slot>=1 && phy_slot<phy_period-3);end
        endcase
      end
      if({en,wn,gn,ub,lb}!=={want_en,want_wn,want_gn,want_bn,want_bn} || address<base_cfg || address>=base_cfg+nwords)
        $fatal(1,"Algorithm pin timing case=%0d phase=%0d A=%h slot=%0d read=%b got=%b expected=%b",cases,dut.u_algorithm.phase,address,phy_slot,dut.pad_read,{en,wn,gn,ub,lb},{want_en,want_wn,want_gn,want_bn,want_bn});
      pin_checks=pin_checks+1;
      phy_prev=1;phy_read_prev=dut.pad_read;phy_address_prev=address;
    end else phy_prev=0;
  end
  reg [21:0] sample_address;
  reg [15:0] sample_expected;
  always @(posedge clk) if(rst_n && dut.spi_start_test) starts=starts+1;
  always @(posedge clk) if(active && rst_n) begin
    if(dut.send_frame_ack) begin
      finished_errors[acks]=errors;finished_details[acks]=details;acks=acks+1;
      op_pos=0;errors=0;details=0;physical_launches=0;physical_captures=0;prior_read=0;
    end
    if(dut.detail_stall) $fatal(1,"Algorithm paused for a report");
    if(dut.flg && !dut.read_pipeline_flush &&
       (dut.before_one_event!==dut.hold_before_one || dut.before_two_event!==dut.hold_before_two || dut.period_event!==dut.period_match))
      $fatal(1,"Algorithm timer event prediction diverged");
    if(dut.read_sample_valid && !dut.read_pipeline_flush) begin
      sample_address=dut.read_due_0?dut.read_address_0:dut.read_address_1;
      sample_expected=dut.read_due_0?dut.read_expected_0:dut.read_expected_1;
      if(physical_captures>=physical_launches || sample_address!==physical_reads[physical_captures])
        $fatal(1,"Sample metadata does not identify physical read address");
      physical_captures=physical_captures+1;
      if(sample_expected!==op_word[op_pos]) $fatal(1,"Wrong read expected word case=%0d pos=%0d expected=%h got=%h",cases,op_pos,op_word[op_pos],sample_expected);
      observe(1,sample_address,dq);
    end
  end
  task add(input bit rd,input integer offset,input [15:0] word_value);
    begin op_read[nops]=rd;op_addr[nops]=base_cfg+offset;op_word[nops]=word_value;nops=nops+1;end
  endtask
  task build_operations;
    integer a,k;
    reg [15:0] first;
    begin
      nops=0;first=(pattern_cfg==2)?16'hffff:16'h0000;
      if(pattern_cfg==10) begin
        for(a=0;a<nwords;a=a+1)add(0,a,0);
        for(a=0;a<nwords;a=a+1)begin add(1,a,0);add(0,a,16'hffff);end
        for(a=0;a<nwords;a=a+1)begin add(1,a,16'hffff);add(0,a,0);end
        for(a=0;a<nwords;a=a+1)add(1,a,0);
        for(a=nwords-1;a>=0;a=a-1)begin add(1,a,0);add(0,a,16'hffff);end
        for(a=nwords-1;a>=0;a=a-1)begin add(1,a,16'hffff);add(0,a,0);end
        for(a=0;a<nwords;a=a+1)add(1,a,0);
      end else if(pattern_cfg<=2 && mode_cfg==2) begin
        for(k=0;k<2;k=k+1) begin
          for(a=0;a<nwords;a=a+1)add(0,a,k?~first:first);
          for(a=0;a<nwords;a=a+1)add(1,a,k?~first:first);
        end
      end else begin
        if(mode_cfg!=1)for(a=0;a<nwords;a=a+1)add(0,a,word_at(pattern_cfg,a));
        if(mode_cfg!=0)for(a=0;a<nwords;a=a+1)add(1,a,word_at(pattern_cfg,a));
      end
    end
  endtask
  task byte_io(input [7:0] value,output [7:0] result);
    integer b;
    begin for(b=7;b>=0;b=b-1)begin mosi=value[b];#111;sclk=1;#1;result[b]=miso;#110;sclk=0;end end
  endtask
  task configure;
    begin
      for(i=0;i<24;i=i+1)cfg[i]=0;
      cfg[0]=8'h55;cfg[1]=chip_cfg;cfg[2]=mode_cfg;cfg[3]=pattern_cfg;
      cfg[4]=base_cfg[7:0];cfg[5]=base_cfg[15:8];cfg[6]=base_cfg[21:16];
      cfg[8]=nwords[7:0];cfg[9]=nwords[15:8];cfg[12]=rounds;cfg[16]=period_cfg;
      cfg[17]=write_cfg;cfg[18]=read_cfg;cfg[19]=detail_cfg;
      checksum=0;for(i=1;i<=21;i=i+1)checksum=checksum+cfg[i];cfg[22]=checksum;cfg[23]=8'haa;
      cs_n=0;#100;for(i=0;i<24;i=i+1)byte_io(cfg[i],unused);#100;cs_n=1;#200;
    end
  endtask
  task poll;
    begin cs_n=0;#100;for(i=0;i<64;i=i+1)byte_io(0,bytes[i]);#100;cs_n=1;#200;end
  endtask
  task run_case(input bit reset_first);
    integer want_details;
    bit summary_format;
    begin
      active=0;
      if(reset_first)begin rst_n=0;#30;@(negedge clk);rst_n=1;end
      for(i=0;i<1024;i=i+1)memory[i]=word_at(pattern_cfg,i);
      memory_changed=~memory_changed;build_operations;
      op_pos=0;round_no=0;writes=0;reads=0;errors=0;details=0;polls=0;
      physical_launches=0;physical_captures=0;prior_read=0;starts=0;acks=0;
      active=1;configure;
      if(replace_cfg) begin
        wait(dut.u_spi_protocol.detail_pending);active=0;starts=0;
        fork
          begin configure;end
          begin
            wait(dut.spi_start_test===1'b1);
            wait(dut.pad_active===1'b0 && dut.flg===1'b0);
            @(negedge clk);
            op_pos=0;round_no=0;errors=0;details=0;polls=0;
            physical_launches=0;physical_captures=0;prior_read=0;acks=0;
            active=1;
          end
        join
      end
      summary_format=(mode_cfg==2 || pattern_cfg==10);
      while(round_no<rounds) begin
        // Deliberately let all passes finish before polling: tests FIFO
        // persistence across phases, overflow, and round-level summary fencing.
        wait(dut.u_spi_protocol.pending_test_complete && !dut.u_spi_protocol.test_busy);
        if(op_pos!=nops || physical_launches!=physical_captures)
          $fatal(1,"Incomplete algorithm case=%0d round=%0d ops=%0d/%0d",cases,round_no,op_pos,nops);
        poll;polls=polls+1;if(polls>100) $fatal(1,"Algorithm report stalled");
        if(summary_format) begin
          frame_loop={bytes[6],bytes[5],bytes[4],bytes[3]};
          if(bytes[0]!==8'h55 || bytes[2]!==8'hff || frame_loop!=round_no || {bytes[10],bytes[9],bytes[8],bytes[7]}!==nwords)
            $fatal(1,"Wrong algorithm report header");
          if(bytes[1]==8'h19)begin
            frame_index={bytes[15],bytes[14],bytes[13],bytes[12]};idx=frame_index-1;
            if(frame_index!=details+1 || idx>=errors || idx>=8 ||
               {bytes[19],bytes[18],bytes[17],bytes[16]}!=={10'd0,error_addr[idx]} ||
               {bytes[21],bytes[20]}!==error_actual[idx] || {bytes[23],bytes[22]}!==error_expected[idx] || bytes[24]!==8'haa)
              $fatal(1,"Wrong algorithm detail across passes case=%0d index=%0d",cases,frame_index);
            details=details+1;all_details=all_details+1;
          end else begin
            reported_errors={bytes[15],bytes[14],bytes[13],bytes[12]};
            want_details=detail_cfg?((finished_errors[round_no]>8)?8:finished_errors[round_no]):0;
            if(bytes[1]!==8'h11 || bytes[16]!==8'haa || reported_errors!=finished_errors[round_no] || finished_details[round_no]!=want_details || bytes[11]!==((finished_errors[round_no]!=0)?8'd1:8'd0))
              $fatal(1,"Wrong accumulated algorithm summary case=%0d got=%0d expected=%0d details=%0d/%0d",cases,reported_errors,errors,details,want_details);
            if(acks!=round_no+1) $fatal(1,"Round ACK count incorrect");
            round_no=round_no+1;
          end
        end else begin
          if(bytes[0]!==8'h55 || bytes[1]!==8'hff || bytes[10]!==8'haa ||
             {bytes[5],bytes[4],bytes[3],bytes[2]}!==round_no || {bytes[9],bytes[8],bytes[7],bytes[6]}!==nwords)
            $fatal(1,"Standalone one-pass report incorrect");
          round_no=round_no+1;
        end
      end
      if(starts!=1 || acks!=rounds || !dut.loop_done) $fatal(1,"Algorithm start/round completion incorrect starts=%0d acks=%0d done=%b",starts,acks,dut.loop_done);
      $display("PASS data case %0d: pattern=%0d mode=%0d N=%0d operations/round=%0d rounds=%0d write=%0d read=%0d faults=%0d",cases,pattern_cfg,mode_cfg,nwords,nops,rounds,write_cfg,read_cfg,fault_cfg);$fflush();
      cases=cases+1;active=0;
    end
  endtask
  initial begin
    if(!$test$plusargs("restart_only")) begin
    for(p=1;p<=2;p=p+1)for(m=0;m<3;m=m+1)for(l=0;l<2;l=l+1)begin
      pattern_cfg=p;mode_cfg=m;nwords=l?3:1;read_cfg=l;write_cfg=(p+m)%3;period_cfg=7;
      fault_cfg=(m==2)?1:0;run_case(1);
    end
    for(m=0;m<2;m=m+1)for(l=0;l<2;l=l+1)for(f=0;f<2;f=f+1)begin
      pattern_cfg=10;mode_cfg=m;nwords=l?3:1;read_cfg=l;write_cfg=(m+l)%3;period_cfg=7;
      fault_cfg=f?2:0;run_case(1);
    end
    for(p=3;p<=8;p=p+1)for(m=0;m<3;m=m+1)begin
      pattern_cfg=p;mode_cfg=m;nwords=3;read_cfg=m%2;write_cfg=p%3;period_cfg=10;
      fault_cfg=0;run_case(1);
    end
    // Completed same-mode restart must begin from phase zero and the first word.
    pattern_cfg=1;mode_cfg=2;nwords=17;read_cfg=1;write_cfg=1;period_cfg=10;fault_cfg=1;run_case(1);run_case(0);
    pattern_cfg=10;mode_cfg=1;nwords=17;fault_cfg=2;detail_cfg=0;run_case(1);run_case(0);
    // Long ascending/descending carries and restart of an active algorithm
    // with unreported records must not leak the previous phase or FIFO data.
    pattern_cfg=10;mode_cfg=1;nwords=577;detail_cfg=1;fault_cfg=2;period_cfg=10;
    read_cfg=0;run_case(1);read_cfg=1;run_case(1);
    end
    pattern_cfg=10;mode_cfg=1;nwords=577;detail_cfg=1;fault_cfg=2;period_cfg=10;read_cfg=1;write_cfg=1;
    replace_cfg=1;run_case(1);replace_cfg=0;
    // Unsupported March write/read combination must not mutate live config
    // or restart the completed test. There is no new wire-format error frame.
    before_starts=starts;active=1;mode_cfg=2;configure;#500;
    if(dut.spi_test_mode!==1 || dut.spi_data_pattern!==10 || starts!=before_starts || dut.pad_active)
      $fatal(1,"Unsupported March configuration was applied");
    chip_cfg=8'h80;mode_cfg=0;configure;#500;
    if(dut.spi_test_mode!==1 || dut.spi_data_pattern!==10 || dut.spi_chip_type!==8'h83 || starts!=before_starts || dut.pad_active)
      $fatal(1,"Unsupported x8 March configuration was applied");
    active=0;
    if($test$plusargs("restart_only"))
      $display("PASS: active March restart, stale-record flush, two complete new rounds, overflow and invalid-combination rejection");
    else $display("PASS: %0d data-table cases, %0d writes, %0d read captures, %0d details; one-pass standalone, two-pair backgrounds, March C 11N, ascending/descending per-address pairs, overflow and restart",cases,all_writes,all_reads,all_details);
    $display("PASS: %0d independent algorithm pin-cycle checks",pin_checks);
    $finish;
  end
  initial begin #40000000;$fatal(1,"Data algorithm watchdog expired pattern=%0d mode=%0d op=%0d/%0d phase=%0d flg=%b busy=%b count=%0d",pattern_cfg,mode_cfg,op_pos,nops,dut.u_algorithm.phase,dut.flg,dut.algorithm_busy,dut.addr_cnt);end
endmodule
