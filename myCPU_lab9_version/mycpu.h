`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD       33      //check
    `define FS_TO_DS_BUS_WD 67
    `define DS_TO_ES_BUS_WD 182
    `define ES_TO_MS_BUS_WD 165
    `define MS_TO_WS_BUS_WD 157 
    `define WS_TO_RF_BUS_WD 39
    `define FW_DATA         39      //is_mfc0, is_load, foward data and register number
    `define WS_TO_FS_BUS_EX 33
    
    `define COUNT        8'b01001000  //$9
    `define COMPARE      8'b01011000  //$11
    `define STATUS       8'b01100000  //$12
    `define CAUSE        8'b01101000  //$13
    `define EPC          8'b01110000  //$14

    `define INTERRUPT    4'b0001
    `define ADEL_IF      4'b0010
    `define REMAIN       4'b0011
    `define OVERFLOW     4'b0100
    `define BREAK        4'b0101
    `define SYSCALL      4'b0110
    `define ADEL_MS      4'b0111
    `define ADES         4'b1000

`endif
