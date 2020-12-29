`include "mycpu.h"

module wb_stage(
    input                           clk           ,
    input                           reset         ,
    //allowin
    output                          ws_allowin    ,
    //from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    //trace debug interface
    output [31:0] debug_wb_pc      ,
    output [ 3:0] debug_wb_rf_wen  ,
    output [ 4:0] debug_wb_rf_wnum ,
    output [31:0] debug_wb_rf_wdata,
    //foward data path
    output [`FW_DATA         -1:0] ws_to_ds_fw    ,
    //flush and exception info
    output                         ex_flush       ,
    output                         ws_ex          ,
    //send exception return addr to fs
    output [`WS_TO_FS_BUS_EX -1:0] ex_return      
);

reg         ws_valid;
wire        ws_ready_go;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
wire        dest_valid;
wire        ws_gr_we;
wire [ 4:0] ws_dest;
wire [31:0] ms_result;
wire [31:0] ws_final_result;
wire [31:0] ws_pc;

wire [ 2:0] cp0_choose;
wire        mtc0_we;
wire        ws_is_mfc0;
wire        ws_is_mtc0;
wire        ws_bd;
wire        eret_flush;
wire [ 4:0] ws_excode;
wire [ 5:0] ext_int_in;
wire [ 7:0] cp0_waddr;
wire [31:0] ws_badvaddr;
wire [31:0] cp0_epc;
wire [31:0] cp0_result;
wire [ 2:0] ws_ex_type;

wire [31:0] ws_rt_value;
wire [31:0] cp0_wdata;

assign cp0_wdata = mtc0_we ? ws_rt_value : ms_result;

assign mtc0_we = ws_valid && ws_is_mtc0 && !ws_ex;
assign ws_ex = (ws_ex_type != 3'b0 && ws_valid) ? 1'b1 : 1'b0;
assign ws_excode = (ws_ex_type == `SYSCALL) ? 5'h08 : 5'h00;
assign ex_flush = (ws_ex || eret_flush) && ws_valid;
assign ext_int_in = 6'b0;

assign {ws_rt_value    ,  //120:89
        ws_bd          ,  //88:88
        ws_ex_type     ,  //87:87
        eret_flush     ,  //84:84
        cp0_waddr      ,  //83:76
        cp0_choose     ,  //75:73
        ws_is_mtc0     ,  //72:72
        ws_is_mfc0     ,  //71:71
        dest_valid     ,  //70:70
        ws_gr_we       ,  //69:69
        ws_dest        ,  //68:64
        ms_result,        //63:32
        ws_pc             //31:0
       } = ms_to_ws_bus_r;

assign ws_final_result = ws_is_mfc0 ? cp0_result : ms_result;

wire        rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
assign ws_to_rf_bus = {rf_we   ,  //37:37
                       rf_waddr,  //36:32
                       rf_wdata   //31:0
                      };

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ex_flush) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

assign rf_we    = ws_gr_we&&ws_valid;
assign rf_waddr = ws_dest;
assign rf_wdata = ws_final_result;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = ws_final_result;

assign ws_to_ds_fw = {ws_valid & dest_valid, ws_dest, ws_final_result};

assign ex_return = {eret_flush, cp0_epc};

cp0_regs ws_cp0_regs(
    .clk        (clk)        ,
    .reset      (reset)      ,
    .mtc0_we    (mtc0_we)    ,
    .ws_ex      (ws_ex)      ,
    .ws_bd      (ws_bd)      ,
    .eret_flush (eret_flush) ,
    .cp0_choose (cp0_choose) ,
    .ws_excode  (ws_excode)  ,
    .ext_int_in (ext_int_in) ,
    .cp0_waddr  (cp0_waddr)  ,
    .cp0_wdata  (cp0_wdata)  ,
    .ws_pc      (ws_pc)      ,
    .ws_badvaddr(ws_badvaddr),
    .epc        (cp0_epc)    ,
    .cp0_rdata  (cp0_result)
);

endmodule


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
    output [31:0] epc        ,
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

assign epc = cp0_epc;

endmodule