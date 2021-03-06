`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus  ,
    //foward data path
    input  [`FW_DATA           :0] es_to_ds_fw   ,
    input  [`FW_DATA         -1:0] ms_to_ds_fw   ,
    input  [`FW_DATA         -1:0] ws_to_ds_fw   ,
    //flush
    input                          ex_flush
);

reg         ds_valid   ;
wire        ds_ready_go;

wire [31                 :0] fs_pc;
reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;
assign fs_pc = fs_to_ds_bus[31:0];

wire [31:0] ds_inst;
wire [31:0] ds_pc  ;
assign {ds_inst,
        ds_pc  } = fs_to_ds_bus_r;

wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

wire        br_taken;
wire [31:0] br_target;

wire        dest_valid;
wire [11:0] alu_op;
wire        load_op;
wire        src1_is_sa;
wire        src1_is_pc;
wire        src2_is_imm;
wire        src2_is_8;
wire        res_from_mem;
wire        gr_we;
wire        mem_we;
wire [ 4:0] dest;
wire [15:0] imm;
wire [31:0] rs_value;
wire [31:0] rt_value;

wire [ 5:0] op;
wire [ 4:0] rs;
wire [ 4:0] rt;
wire [ 4:0] rd;
wire [ 4:0] sa;
wire [ 5:0] func;
wire [25:0] jidx;
wire [63:0] op_d;
wire [31:0] rs_d;
wire [31:0] rt_d;
wire [31:0] rd_d;
wire [31:0] sa_d;
wire [63:0] func_d;

wire        inst_addu;
wire        inst_subu;
wire        inst_slt;
wire        inst_sltu;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_nor;
wire        inst_sll;
wire        inst_srl;
wire        inst_sra;
wire        inst_addiu;
wire        inst_lui;
wire        inst_lw;
wire        inst_sw;
wire        inst_beq;
wire        inst_bne;
wire        inst_jal;
wire        inst_jr;
//lab6 add
wire        inst_add;
wire        inst_addi;
wire        inst_sub;
wire        inst_slti;
wire        inst_sltiu;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_sllv;
wire        inst_srav;
wire        inst_srlv;
wire        inst_mult;
wire        inst_multu;
wire        inst_div;
wire        inst_divu;
wire        inst_mfhi;
wire        inst_mflo;
wire        inst_mthi;
wire        inst_mtlo;
//lab7 add
wire        inst_bgez;
wire        inst_bgtz;
wire        inst_blez;
wire        inst_bltz;
wire        inst_j;
wire        inst_bltzal;
wire        inst_bgezal;
wire        inst_jalr;
wire        inst_lb;
wire        inst_lbu;
wire        inst_lh;
wire        inst_lhu;
wire        inst_lwl;
wire        inst_lwr;
wire        inst_sb;
wire        inst_sh;
wire        inst_swl;
wire        inst_swr;
//lab8 add
wire        inst_mfc0;
wire        inst_mtc0;
wire        inst_eret;
wire        inst_syscall;

wire [1:0] mult_op;
wire [1:0]  div_op;

wire        HI_wen;
wire        LO_wen;
wire [ 1:0] HI_LO_wen;
wire [ 1:0] HI_LO_mv;

wire        dst_is_r31;  
wire        dst_is_rt;   

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        rs_eq_rt;
wire        rs_eq_zero;
wire        rs_more_or_eq_zero;
wire        rs_more_zero;
wire        rs_less_or_eq_zero;
wire        rs_less_zero;

wire ds_is_mfc0;
wire es_is_mfc0;
wire ms_is_mfc0;

wire ds_is_mtc0;

wire [2:0] sel;
wire [7:0] rd_sel;
assign     sel    = ds_inst[2:0];
assign     rd_sel = {rd, sel};

wire [2:0] cp0_choose;
assign cp0_choose[0] = (rd == 12 && sel == 0);  //status
assign cp0_choose[1] = (rd == 13 && sel == 0);  //cause
assign cp0_choose[2] = (rd == 14 && sel == 0);  //epc

wire [2:0] ex_type;
assign ex_type = inst_syscall ? `SYSCALL : 3'b0;

reg  bd_valid;
wire ds_bd;

assign ds_bd = inst_syscall && bd_valid;

always @(posedge clk) begin
    if(reset)
        bd_valid <= 1'b0;
    else if(br_taken && !inst_syscall)
        bd_valid <= 1'b1;
    else
        bd_valid <= 1'b0;
end

wire        condition_jump;
assign condition_jump = inst_beq  || inst_bne  || inst_bgez   || inst_bgtz || 
                        inst_blez || inst_bltz || inst_bltzal || inst_bgezal;

assign br_bus       = {br_taken,br_target};
assign load_op      = inst_lw  | inst_lb  | inst_lbu | inst_lh |
                      inst_lhu | inst_lwl | inst_lwr ;

assign mult_op[1] = inst_multu ? 1'b1 : 1'b0;
assign mult_op[0] = inst_mult  ? 1'b1 : 1'b0;
assign div_op[ 1] = inst_divu  ? 1'b1 : 1'b0;
assign div_op[ 0] = inst_div   ? 1'b1 : 1'b0;

assign HI_LO_wen = {HI_wen,LO_wen};

assign HI_LO_mv[1] = inst_mfhi;
assign HI_LO_mv[0] = inst_mflo;

assign ds_to_es_bus = {ds_bd       ,  //174:174
                       ex_type     ,  //173:173
                       inst_eret   ,  //170:170
                       rd_sel      ,  //169:162
                       cp0_choose  ,  //161:159
                       ds_is_mtc0  ,  //158:158
                       ds_is_mfc0  ,  //157:157
                       inst_swl    ,  //156:156
                       inst_swr    ,  //155:155
                       inst_lwl    ,  //154:154
                       inst_lwr    ,  //153:153
                       inst_sw     ,  //152:152
                       inst_sb     ,  //151:151
                       inst_sh     ,  //150:150
                       inst_lhu    ,  //149:149
                       inst_lh     ,  //148:148
                       inst_lbu    ,  //147:147
                       inst_lb     ,  //146:146
                       inst_lw     ,  //145:145
                       HI_LO_mv    ,  //144:143
                       mult_op     ,  //142:141
                       div_op      ,  //140:139
                       HI_LO_wen   ,  //138:137
                       dest_valid  ,  //136:136
                       alu_op      ,  //135:124
                       load_op     ,  //123:123
                       src1_is_sa  ,  //122:122
                       src1_is_pc  ,  //121:121
                       src2_is_imm ,  //120:120
                       src2_is_8   ,  //119:119
                       gr_we       ,  //118:118
                       mem_we      ,  //117:117
                       dest        ,  //116:112
                       imm         ,  //111:96
                       rs_value    ,  //95 :64
                       rt_value    ,  //63 :32
                       ds_pc          //31 :0
                      };

assign dest_valid = (inst_sw   | inst_beq     | inst_bne  | inst_jr   |
                     inst_mult | inst_multu   | inst_div  | inst_divu |
                     inst_mthi | inst_mtlo    | inst_bgez | inst_bgtz |
                     inst_blez | inst_bltz    | inst_j    | inst_sb   |
                     inst_sh   | inst_swl     | inst_swr  | inst_mtc0 |
                     inst_eret | inst_syscall ) ? 1'b0 : 1'b1;

wire        es_is_load;
wire        es_valid  ;
wire        ms_valid  ;
wire        ws_valid  ;
wire        es_related;
wire        ms_related;
wire        ws_related;
wire        block     ;
wire [ 4:0] dest_es   ;
wire [ 4:0] dest_ms   ;
wire [ 4:0] dest_ws   ;
wire [31:0] data_es   ;
wire [31:0] data_ms   ;
wire [31:0] data_ws   ;


assign ds_is_mfc0 = inst_mfc0;
assign ds_is_mtc0 = inst_mtc0;

assign {es_is_mfc0, es_is_load, es_valid, dest_es, data_es} = es_to_ds_fw;
assign {ms_is_mfc0            , ms_valid, dest_ms, data_ms} = ms_to_ds_fw;
assign {                        ws_valid, dest_ws, data_ws} = ws_to_ds_fw;

assign es_related = (rs == dest_es || rt == dest_es) && dest_es!=5'b00000 && es_valid;
assign ms_related = (rs == dest_ms || rt == dest_ms) && dest_ms!=5'b00000 && ms_valid;
assign ws_related = (rs == dest_ws || rt == dest_ws) && dest_ws!=5'b00000 && ws_valid;

assign block = es_is_load && es_related ||
               es_is_mfc0 && es_related ||
               ms_is_mfc0 && ms_related ;
              
assign ds_ready_go    = !block; 
assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid = ds_valid && ds_ready_go;
always @(posedge clk) begin
    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

always @(posedge clk) begin     //check
    if(reset) begin
        ds_valid <=1'b0;
    end
    else if(ex_flush) begin
        ds_valid <= 1'b0;
    end
    else if(ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end
end

assign op   = ds_inst[31:26];
assign rs   = ds_inst[25:21];
assign rt   = ds_inst[20:16];
assign rd   = ds_inst[15:11];
assign sa   = ds_inst[10: 6];
assign func = ds_inst[ 5: 0];
assign imm  = ds_inst[15: 0];
assign jidx = ds_inst[25: 0];

decoder_6_64 u_dec0(.in(op  ), .out(op_d  ));
decoder_6_64 u_dec1(.in(func), .out(func_d));
decoder_5_32 u_dec2(.in(rs  ), .out(rs_d  ));
decoder_5_32 u_dec3(.in(rt  ), .out(rt_d  ));
decoder_5_32 u_dec4(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec5(.in(sa  ), .out(sa_d  ));

assign inst_addu   = op_d[6'h00] & func_d[6'h21] & sa_d[5'h00];     
assign inst_subu   = op_d[6'h00] & func_d[6'h23] & sa_d[5'h00];
assign inst_slt    = op_d[6'h00] & func_d[6'h2a] & sa_d[5'h00];
assign inst_sltu   = op_d[6'h00] & func_d[6'h2b] & sa_d[5'h00];
assign inst_and    = op_d[6'h00] & func_d[6'h24] & sa_d[5'h00];
assign inst_or     = op_d[6'h00] & func_d[6'h25] & sa_d[5'h00];
assign inst_xor    = op_d[6'h00] & func_d[6'h26] & sa_d[5'h00];
assign inst_nor    = op_d[6'h00] & func_d[6'h27] & sa_d[5'h00];
assign inst_sll    = op_d[6'h00] & func_d[6'h00] & rs_d[5'h00];
assign inst_srl    = op_d[6'h00] & func_d[6'h02] & rs_d[5'h00];
assign inst_sra    = op_d[6'h00] & func_d[6'h03] & rs_d[5'h00];
assign inst_addiu  = op_d[6'h09];
assign inst_lui    = op_d[6'h0f] & rs_d[5'h00];
assign inst_lw     = op_d[6'h23];
assign inst_sw     = op_d[6'h2b];
assign inst_beq    = op_d[6'h04];
assign inst_bne    = op_d[6'h05];
assign inst_jal    = op_d[6'h03];
assign inst_jr     = op_d[6'h00] & func_d[6'h08] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
//lab6 add
assign inst_add    = op_d[6'h00] & func_d[6'h20] & sa_d[5'h00];
assign inst_addi   = op_d[6'h08];
assign inst_sub    = op_d[6'h00] & func_d[6'h22] & sa_d[5'h00];
assign inst_slti   = op_d[6'h0a];
assign inst_sltiu  = op_d[6'h0b];
assign inst_andi   = op_d[6'h0c];
assign inst_ori    = op_d[6'h0d];
assign inst_xori   = op_d[6'h0e];
assign inst_sllv   = op_d[6'h00] & func_d[6'h04] & sa_d[5'h00];
assign inst_srav   = op_d[6'h00] & func_d[6'h07] & sa_d[5'h00];
assign inst_srlv   = op_d[6'h00] & func_d[6'h06] & sa_d[5'h00];
assign inst_mult   = op_d[6'h00] & func_d[6'h18] & sa_d[5'h00];
assign inst_multu  = op_d[6'h00] & func_d[6'h19] & sa_d[5'h00];
assign inst_div    = op_d[6'h00] & func_d[6'h1a] & sa_d[5'h00];
assign inst_divu   = op_d[6'h00] & func_d[6'h1b] & sa_d[5'h00];
assign inst_mfhi   = op_d[6'h00] & func_d[6'h10] & sa_d[5'h00];
assign inst_mflo   = op_d[6'h00] & func_d[6'h12] & sa_d[5'h00];
assign inst_mthi   = op_d[6'h00] & func_d[6'h11] & sa_d[5'h00];
assign inst_mtlo   = op_d[6'h00] & func_d[6'h13] & sa_d[6'h00];
//lab7 add
assign inst_bgez   = op_d[6'h01] & rt_d[5'h01];
assign inst_bgtz   = op_d[6'h07];
assign inst_blez   = op_d[6'h06];
assign inst_bltz   = op_d[6'h01] & rt_d[5'h00];
assign inst_j      = op_d[6'h02];
assign inst_bltzal = op_d[6'h01] & rt_d[5'h10];
assign inst_bgezal = op_d[6'h01] & rt_d[5'h11];
assign inst_jalr   = op_d[6'h00] & func_d[6'h09];
assign inst_lb     = op_d[6'h20];
assign inst_lbu    = op_d[6'h24];
assign inst_lh     = op_d[6'h21];
assign inst_lhu    = op_d[6'h25];
assign inst_lwl    = op_d[6'h22];
assign inst_lwr    = op_d[6'h26];
assign inst_sb     = op_d[6'h28];
assign inst_sh     = op_d[6'h29];
assign inst_swl    = op_d[6'h2a];
assign inst_swr    = op_d[6'h2e];
//lab8 add
assign inst_mtc0    = op_d[6'h10] & rs_d[5'h04];
assign inst_mfc0    = op_d[6'h10] & rs_d[5'h00];
assign inst_eret    = op_d[6'h10] & func_d[6'h18];
assign inst_syscall = op_d[6'h00] & func_d[6'h0c];

assign alu_op[ 0] = inst_addu | inst_addiu  | inst_lw   | inst_sw     |
                    inst_jal  | inst_add    | inst_addi | inst_bltzal |
                    inst_jalr | inst_bgezal | inst_lb   | inst_lbu    |
                    inst_lh   | inst_lhu    | inst_sb   | inst_sh     |
                    inst_lwl  | inst_lwr    | inst_swl  | inst_swr    ;
assign alu_op[ 1] = inst_subu | inst_sub;
assign alu_op[ 2] = inst_slt  | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltiu;
assign alu_op[ 4] = inst_and  | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or   | inst_ori;
assign alu_op[ 7] = inst_xor  | inst_xori;
assign alu_op[ 8] = inst_sll  | inst_sllv;
assign alu_op[ 9] = inst_srl  | inst_srlv;
assign alu_op[10] = inst_sra  | inst_srav;
assign alu_op[11] = inst_lui;

assign src1_is_sa   = inst_sll   | inst_srl | inst_sra;
assign src1_is_pc   = inst_jal   | inst_bgezal | inst_bltzal | inst_jalr;
assign src2_is_imm  = inst_addiu | inst_lui  | inst_lw    | inst_sw   |
                      inst_addi  | inst_slti | inst_sltiu | inst_andi |
                      inst_ori   | inst_xori | inst_lb    | inst_lbu  |
                      inst_lh    | inst_lhu  | inst_sb    | inst_sh   |
                      inst_lwl   | inst_lwr  | inst_swl   | inst_swr  ;
assign src2_is_8    = inst_jal   | inst_bgezal | inst_bltzal | inst_jalr;
assign res_from_mem = inst_lw | inst_lb | inst_lbu | inst_lh |
                      inst_lhu;
assign dst_is_r31   = inst_jal | inst_bltzal | inst_bgezal;
assign dst_is_rt    = inst_addiu | inst_lui   | inst_lw   | inst_addi |
                      inst_slti  | inst_sltiu | inst_andi | inst_ori  |
                      inst_xori  | inst_lb    | inst_lbu  | inst_lh   |
                      inst_lhu   | inst_lwl   | inst_lwr  | inst_mfc0 ;
assign gr_we        = ~inst_sw   & ~inst_beq  & ~inst_bne  & ~inst_jr 
                    & ~inst_j    & ~inst_bgez & ~inst_bgtz & ~inst_blez
                    & ~inst_bltz & ~inst_sb   & ~inst_sh   & ~inst_swl
                    & ~inst_swr  & ~inst_mtc0 & ~inst_eret & ~inst_syscall;
assign mem_we       = inst_sw | inst_sb | inst_sh | inst_swl | inst_swr;

assign dest         = dst_is_r31 ? 5'd31 :
                      dst_is_rt  ? rt    : 
                                   rd;

assign HI_wen = inst_mult | inst_multu | inst_div | inst_divu | inst_mthi;
assign LO_wen = inst_mult | inst_multu | inst_div | inst_divu | inst_mtlo;

assign rf_raddr1 = rs;
assign rf_raddr2 = rt;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );



assign rs_value = (dest_es == rs && dest_es!=5'b00000 && es_valid)? data_es  :
                  (dest_ms == rs && dest_ms!=5'b00000 && ms_valid)? data_ms  :
                  (dest_ws == rs && dest_ws!=5'b00000 && ws_valid)? data_ws  :
                                                                    rf_rdata1;

assign rt_value = (dest_es == rt && dest_es!=5'b00000 && es_valid)? data_es  :
                  (dest_ms == rt && dest_ms!=5'b00000 && ms_valid)? data_ms  :
                  (dest_ws == rt && dest_ws!=5'b00000 && ws_valid)? data_ws  :
                                                                    rf_rdata2;

assign rs_eq_rt           = (rs_value == rt_value );
assign rs_eq_zero         = (rs_value == 32'h00000000);
assign rs_more_zero       = (rs_value[31] == 0 && !rs_eq_zero);
assign rs_less_zero       = (rs_value[31] == 1);
assign rs_more_or_eq_zero = (rs_more_zero || rs_eq_zero);
assign rs_less_or_eq_zero = (rs_less_zero || rs_eq_zero);

assign br_taken = (   inst_beq  &&  rs_eq_rt
                   || inst_bne  &&  !rs_eq_rt
                   || inst_bgez &&  rs_more_or_eq_zero
                   || inst_bgtz &&  rs_more_zero
                   || inst_blez &&  rs_less_or_eq_zero
                   || inst_bltz &&  rs_less_zero
                   || inst_bgezal && rs_more_or_eq_zero
                   || inst_bltzal && rs_less_zero
                   || inst_j
                   || inst_jal
                   || inst_jr
                   || inst_jalr
                  ) && ds_valid;

assign br_target = (condition_jump      ) ? (fs_pc + {{14{imm[15]}}, imm[15:0], 2'b0}) :
                   (inst_jr || inst_jalr) ? rs_value :
                  /*inst_jal || inst_j*/    {fs_pc[31:28], jidx[25:0], 2'b0};



endmodule
