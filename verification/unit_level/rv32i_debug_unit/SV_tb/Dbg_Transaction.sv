`include "rv32i_defines.vh"
class Dbg_Transaction;
    rand logic        bus_start;
    rand logic [14:0] bus_addr;
    rand logic        bus_we;
    rand logic [31:0] bus_wdata;
    rand logic debug_halt_i;
    rand logic debug_resume_i;
    rand logic trap_i;
    rand logic [5:0] exc_cause_i;
    rand logic dbg_ack_i;
    rand logic [31:0] regfile_rdata_i;
    rand logic [31:0] csr_rdata_i;
    rand logic [31:0] pc_if_i;
    rand logic [31:0] pc_id_i;
    rand logic instr_valid_id_i;
    rand logic sleeping_i;

    logic rst_n;
    logic debug_req_i;
    logic [14:0] debug_addr_i;
    logic debug_we_i;
    logic [31:0] debug_wdata_i;
    logic debug_gnt_o;
    logic debug_rvalid_o;
    logic [31:0] debug_rdata_o;
    logic debug_halted_o;
    logic [`DBG_SETS_W-1:0] settings_o;
    logic stall_o;
    logic dbg_req_o;
    logic regfile_rreq_o;
    logic [4:0] regfile_raddr_o;
    logic regfile_wreq_o;
    logic [4:0] regfile_waddr_o;
    logic [31:0] regfile_wdata_o;
    logic csr_req_o;
    logic [11:0] csr_addr_o;
    logic csr_we_o;
    logic [31:0] csr_wdata_o;
    logic jump_req_o;
    logic [31:0] jump_addr_o;

    constraint c_bus
    {
        bus_start dist {1 := 40, 0 := 60};
        bus_we dist {1 := 50, 0 := 50};
        bus_addr[1:0] == 2'b00;
        bus_addr[14:8] dist {7'h00 := 35, 7'h20 := 15, 7'h04 := 25, [7'h40:7'h7F] :/ 20, [7'h01:7'h3F] :/ 5};
        bus_addr[7:2] dist {[6'h00:6'h03] :/ 70, [6'h04:6'h3F] :/ 30};
    }

    constraint c_core
    {
        debug_halt_i dist {1 := 3, 0 := 97};
        debug_resume_i dist {1 := 4, 0 := 96};
        trap_i dist {1 := 3, 0 := 97};
        dbg_ack_i dist {1 := 40, 0 := 60};
        sleeping_i dist {1 := 20, 0 := 80};
    }

    function void display(string tag="TX");
        $display("[%s] req=%b we=%b addr=%h wdata=%h | gnt=%b rv=%b rdata=%h | halted=%b stall=%b dreq=%b sets=%b rreq=%b wreq=%b csr=%b%b jmp=%b",
                 tag, debug_req_i, debug_we_i, debug_addr_i, debug_wdata_i, debug_gnt_o, debug_rvalid_o, debug_rdata_o,
                 debug_halted_o, stall_o, dbg_req_o, settings_o, regfile_rreq_o, regfile_wreq_o, csr_req_o, csr_we_o, jump_req_o);
    endfunction

    function Dbg_Transaction do_copy();
        Dbg_Transaction copy;
        copy = new();
        copy.bus_start = this.bus_start;
        copy.bus_addr = this.bus_addr;
        copy.bus_we = this.bus_we;
        copy.bus_wdata = this.bus_wdata;
        copy.rst_n = this.rst_n;
        copy.debug_req_i = this.debug_req_i;
        copy.debug_addr_i = this.debug_addr_i;
        copy.debug_we_i = this.debug_we_i;
        copy.debug_wdata_i = this.debug_wdata_i;
        copy.debug_halt_i = this.debug_halt_i;
        copy.debug_resume_i = this.debug_resume_i;
        copy.trap_i = this.trap_i;
        copy.exc_cause_i = this.exc_cause_i;
        copy.dbg_ack_i = this.dbg_ack_i;
        copy.regfile_rdata_i = this.regfile_rdata_i;
        copy.csr_rdata_i = this.csr_rdata_i;
        copy.pc_if_i = this.pc_if_i;
        copy.pc_id_i = this.pc_id_i;
        copy.instr_valid_id_i = this.instr_valid_id_i;
        copy.sleeping_i = this.sleeping_i;
        copy.debug_gnt_o = this.debug_gnt_o;
        copy.debug_rvalid_o = this.debug_rvalid_o;
        copy.debug_rdata_o = this.debug_rdata_o;
        copy.debug_halted_o = this.debug_halted_o;
        copy.settings_o = this.settings_o;
        copy.stall_o = this.stall_o;
        copy.dbg_req_o = this.dbg_req_o;
        copy.regfile_rreq_o = this.regfile_rreq_o;
        copy.regfile_raddr_o = this.regfile_raddr_o;
        copy.regfile_wreq_o = this.regfile_wreq_o;
        copy.regfile_waddr_o = this.regfile_waddr_o;
        copy.regfile_wdata_o = this.regfile_wdata_o;
        copy.csr_req_o = this.csr_req_o;
        copy.csr_addr_o = this.csr_addr_o;
        copy.csr_we_o = this.csr_we_o;
        copy.csr_wdata_o = this.csr_wdata_o;
        copy.jump_req_o = this.jump_req_o;
        copy.jump_addr_o = this.jump_addr_o;
        return copy;
    endfunction
endclass
