`include "mycpu.h"

module cp0_regs(
    input         clk        ,
    input         reset      ,
    input         mtc0_we    ,
    input         ws_ex      ,
    input         ws_bd      ,
    input         eret_flush ,
    input  [ 2:0] cp0_choose ,
    input  [ 4:0] ws_excode  ,
    input  [ 5:0] ext_int_in ,
    input  [ 7:0] cp0_waddr  ,
    input  [31:0] cp0_wdata  ,
    input  [31:0] ws_pc      ,
    input  [31:0] ws_badvaddr,
    output [31:0] cp0_rdata
);

wire        count_eq_compare;

//cp0 status
wire   cp0_status_bev;
assign cp0_status_bev = 1'b1;

reg [7:0] cp0_status_im;
always @(posedge clk) begin
    if(mtc0_we && cp0_waddr == `STATUS)
        cp0_status_im <= cp0_wdata[15:8];
end

reg cp0_status_exl;
always @(posedge clk) begin
    if(reset)
        cp0_status_exl <= 1'b0;
    else if(ws_ex)
        cp0_status_exl <= 1'b1;
    else if(eret_flush)
        cp0_status_exl <= 1'b0;
    else if(mtc0_we && cp0_waddr == `STATUS)
        cp0_status_exl <= cp0_wdata[1];
end

reg cp0_status_ie;
always @(posedge clk) begin
    if(reset)
        cp0_status_ie <= 1'b0;
    else if(mtc0_we && cp0_waddr == `STATUS)
        cp0_status_ie <= cp0_wdata[0];
end

//cp0 cause
reg cp0_cause_bd;
always @(posedge clk) begin
    if(reset)
        cp0_cause_bd <= 1'b0;
    else if(ws_ex && !cp0_status_exl)
        cp0_cause_bd <= ws_bd;
end

reg cp0_cause_ti;
always @(posedge clk) begin
    if(reset)
        cp0_cause_ti <= 1'b0;
    else if(mtc0_we && cp0_waddr == `COMPARE)
        cp0_cause_ti <= 1'b0;
    else if(count_eq_compare)
        cp0_cause_ti <= 1'b1;
end

reg [7:0] cp0_cause_ip;//ip7----ip2
always @(posedge clk) begin
    if(reset)
        cp0_cause_ip[7:2] <= 6'b0;
    else begin
        cp0_cause_ip[7]   <= ext_int_in[5] | cp0_cause_ti;
        cp0_cause_ip[6:2] <= ext_int_in[4:0];
    end
end

always @(posedge clk) begin
    if(reset)
        cp0_cause_ip[1:0] <= 2'b0;
    else if(mtc0_we && cp0_waddr == `CAUSE)
        cp0_cause_ip[1:0] <= cp0_wdata[9:8];
end

reg [4:0] cp0_cause_excode;
always @(posedge clk) begin
    if(reset)
        cp0_cause_excode <= 5'b0;
    else if(ws_ex)
        cp0_cause_excode <= ws_excode;
end

//cp0 epc
reg [31:0] cp0_epc;
always @(posedge clk) begin
    if(ws_ex && !cp0_status_exl)
        cp0_epc <= ws_bd ? ws_pc -3'h4 : ws_pc;
    else if(mtc0_we && cp0_waddr == `EPC)
        cp0_epc <= cp0_wdata;
end

//cp0 badvaddr
/*
reg [31:0] cp0_badvaddr;
always @(posedge clk) begin
    if(ws_ex && ws_excode == `EXADEL)
        cp0_badvaddr <= ws_badvaddr;
end
*/

//cp0 count
reg        tick;
reg [31:0] cp0_count;
always @(posedge clk) begin
    if(reset)
        tick <= 1'b0;
    else 
        tick <= ~tick;
    
    if(mtc0_we && cp0_waddr == `COUNT)
        cp0_count <= cp0_wdata;
    else if(tick)
        cp0_count <= cp0_count + 1'b1;
end

//cp0 compare
reg [31:0] cp0_compare;
always @(posedge clk) begin
    if(mtc0_we && cp0_waddr == `COMPARE)
        cp0_compare <= cp0_wdata;
end


wire [31:0] cp0_status;
wire [31:0] cp0_cause;

assign cp0_status = {9'b0, cp0_status_bev, 6'b0, cp0_status_im, 6'b0, cp0_status_exl, cp0_status_ie};
assign cp0_cause  = {cp0_cause_bd, cp0_cause_ti, 14'b0, cp0_cause_ip, 1'b0, cp0_cause_excode, 2'b0};

assign cp0_rdata = cp0_choose == 3'b001 ? cp0_status   :
                   cp0_choose == 3'b010 ? cp0_cause    :
                   cp0_choose == 3'b100 ? cp0_epc      :
                   //cp0_choose == 3'b100 ? cp0_badvaddr :
                   //cp0_choose == 3'b101 ? cp0_count    :
                   //cp0_choose == 3'b110 ? cp0_compare  :
                                          31'b0        ;

assign count_eq_compare = (cp0_count == cp0_compare);

endmodule