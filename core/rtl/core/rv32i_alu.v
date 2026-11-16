`include "rv32i_defines.vh"

module rv32i_alu
(
    input  [`ALU_OP_WIDTH-1:0] operator_i,   // source ID stage Decoder
    input  [31:0]              operand_a_i,  // A
    input  [31:0]              operand_b_i,  // B
    // Adder output
    output [31:0]              adder_result_o,
    // Main outputs
    output reg [31:0]          result_o,
    output                     comparison_result_o
);
    // bit reversal for SLL
    wire [31:0] operand_a_rev;
    genvar k;
    generate
        for (k = 0; k < 32; k = k + 1)
        begin
            assign operand_a_rev[k] = operand_a_i[31-k];
        end
    endgenerate

    //=========================================
    // Shared Adder — ADD, SUB, comparisons
    //=========================================
    reg  adder_op_b_negate;
    wire [31:0] operand_b_neg;
    wire [31:0] adder_result;

    always @(*) begin
        adder_op_b_negate = 1'b0;
        case (operator_i)
            `ALU_SUB:   adder_op_b_negate = 1'b1; // A - B
            `ALU_EQ:    adder_op_b_negate = 1'b1; // A - B == 0
            `ALU_NE:    adder_op_b_negate = 1'b1; // A - B != 0
            `ALU_GTU:   adder_op_b_negate = 1'b1; // A > B unsigned
            `ALU_GEU:   adder_op_b_negate = 1'b1; // A >= B unsigned
            `ALU_LTU:   adder_op_b_negate = 1'b1; // A < B unsigned
            `ALU_LEU:   adder_op_b_negate = 1'b1; // A <= B unsigned
            `ALU_GTS:   adder_op_b_negate = 1'b1; // A > B signed
            `ALU_GES:   adder_op_b_negate = 1'b1; // A >= B signed
            `ALU_LTS:   adder_op_b_negate = 1'b1; // A < B signed
            `ALU_LES:   adder_op_b_negate = 1'b1; // A <= B signed
            `ALU_SLTS:  adder_op_b_negate = 1'b1; // set (A < B) signed
            `ALU_SLTU:  adder_op_b_negate = 1'b1; // set (A < B) unsigned
            `ALU_SLETS: adder_op_b_negate = 1'b1; // set (A <= B) signed
            `ALU_SLETU: adder_op_b_negate = 1'b1; // set (A <= B) unsigned
            default:    adder_op_b_negate = 1'b0;
        endcase
    end

    // two's complement subtraction: A - B = A + ~B + 1
    assign operand_b_neg  = operand_b_i ^ {32{adder_op_b_negate}};
    assign adder_result   = operand_a_i + operand_b_neg + {31'b0, adder_op_b_negate};
    assign adder_result_o = adder_result;

    //=========================================
    // Shifter
    //=========================================
    wire        shift_left;
    wire        shift_arithmetic;
    wire [31:0] shift_op_a;
    wire [31:0] shift_right_result;
    wire [31:0] shift_left_result;
    wire [31:0] shift_result;

    assign shift_left       = (operator_i == `ALU_SLL);
    assign shift_arithmetic = (operator_i == `ALU_SRA);
    assign shift_op_a       = shift_left ? operand_a_rev : operand_a_i;
    // one right shifter for SRL/SRA (and SLL on the bit-reversed operand):
    // shift in the sign bit only for SRA
    wire        shift_fill = shift_arithmetic & shift_op_a[31];
    wire [31:0] shift_fill_mask = ~(32'hFFFF_FFFF >> operand_b_i[4:0]);
    assign shift_right_result = (shift_op_a >> operand_b_i[4:0]) | ({32{shift_fill}} & shift_fill_mask);

    genvar j;
    generate
        for (j = 0; j < 32; j = j + 1)
        begin
            assign shift_left_result[j] = shift_right_result[31-j];
        end
    endgenerate

    assign shift_result = shift_left ? shift_left_result : shift_right_result;

    //=========================================
    // Comparator
    //=========================================
    reg  cmp_signed;
    wire is_equal;
    reg  is_greater_equal;
    reg  cmp_result;

    always @(*) begin
        cmp_signed = 1'b0;
        case (operator_i)
            `ALU_GTS:   cmp_signed = 1'b1;
            `ALU_GES:   cmp_signed = 1'b1;
            `ALU_LTS:   cmp_signed = 1'b1;
            `ALU_LES:   cmp_signed = 1'b1;
            `ALU_SLTS:  cmp_signed = 1'b1;
            `ALU_SLETS: cmp_signed = 1'b1;
            default:    cmp_signed = 1'b0;
        endcase
    end

    assign is_equal        = (adder_result == 32'b0);

    always @(*) begin
        if ((operand_a_i[31] ^ operand_b_i[31]) == 1'b0)
            is_greater_equal = (adder_result[31] == 1'b0);
        else
            is_greater_equal = operand_a_i[31] ^ cmp_signed;
    end

    always @(*) begin
        cmp_result = is_equal;
        case (operator_i)
            `ALU_EQ:    cmp_result = is_equal;
            `ALU_NE:    cmp_result = ~is_equal;
            `ALU_GTS:   cmp_result = is_greater_equal & ~is_equal;
            `ALU_GTU:   cmp_result = is_greater_equal & ~is_equal;
            `ALU_GES:   cmp_result = is_greater_equal;
            `ALU_GEU:   cmp_result = is_greater_equal;
            `ALU_LTS:   cmp_result = ~is_greater_equal;
            `ALU_SLTS:  cmp_result = ~is_greater_equal;
            `ALU_LTU:   cmp_result = ~is_greater_equal;
            `ALU_SLTU:  cmp_result = ~is_greater_equal;
            `ALU_LES:   cmp_result = ~is_greater_equal | is_equal;
            `ALU_LEU:   cmp_result = ~is_greater_equal | is_equal;
            `ALU_SLETS: cmp_result = ~is_greater_equal | is_equal;
            `ALU_SLETU: cmp_result = ~is_greater_equal | is_equal;
            default:    cmp_result = is_equal;
        endcase
    end

    assign comparison_result_o = cmp_result;

    //=========================================
    // Result mux
    //=========================================
    always @(*) begin
        result_o = 32'b0;
        case (operator_i)
            `ALU_AND:   result_o = operand_a_i & operand_b_i;
            `ALU_OR:    result_o = operand_a_i | operand_b_i;
            `ALU_XOR:   result_o = operand_a_i ^ operand_b_i;
            `ALU_ADD:   result_o = adder_result;
            `ALU_SUB:   result_o = adder_result;
            `ALU_SLL:   result_o = shift_result;
            `ALU_SRL:   result_o = shift_result;
            `ALU_SRA:   result_o = shift_result;
            `ALU_SLTS:  result_o = {31'b0, cmp_result};
            `ALU_SLTU:  result_o = {31'b0, cmp_result};
            `ALU_SLETS: result_o = {31'b0, cmp_result};
            `ALU_SLETU: result_o = {31'b0, cmp_result};
            `ALU_EQ:    result_o = {31'b0, cmp_result};
            `ALU_NE:    result_o = {31'b0, cmp_result};
            `ALU_GTU:   result_o = {31'b0, cmp_result};
            `ALU_GEU:   result_o = {31'b0, cmp_result};
            `ALU_LTU:   result_o = {31'b0, cmp_result};
            `ALU_LEU:   result_o = {31'b0, cmp_result};
            `ALU_GTS:   result_o = {31'b0, cmp_result};
            `ALU_GES:   result_o = {31'b0, cmp_result};
            `ALU_LTS:   result_o = {31'b0, cmp_result};
            `ALU_LES:   result_o = {31'b0, cmp_result};
            default:    result_o = 32'b0;
        endcase
    end

endmodule
