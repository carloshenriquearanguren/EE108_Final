module song_reader (
    input clk,
    input reset,
    input play,
    input [1:0] song,
    input beat,
    output song_done,

    // Voice 0
    output reg [5:0] note0,
    output reg [5:0] duration0,
    output reg load_note0,

    // Voice 1
    output reg [5:0] note1,
    output reg [5:0] duration1,
    output reg load_note1,

    // Voice 2
    output reg [5:0] note2,
    output reg [5:0] duration2,
    output reg load_note2
);

    localparam S_IDLE       = 3'd0;
    localparam S_READ       = 3'd1;
    localparam S_WAIT_ROM   = 3'd2;
    localparam S_PARSE      = 3'd3;
    localparam S_WAIT_TIME  = 3'd4;
    localparam S_DONE       = 3'd5;

    // Wires for current state (output of flip-flops)
    wire [2:0] state;
    wire [6:0] note_index;
    wire [5:0] wait_counter;
    wire [1:0] next_voice_q;

    // Registers for next state logic
    reg [2:0] next_state;
    reg [6:0] next_note_index;
    reg [5:0] next_wait_counter;
    reg [1:0] next_next_voice;
    reg done;

    // Sequential Logic
    dffr #(3) state_ff (.clk(clk), .r(reset), .d(next_state), .q(state));
    dffr #(7) note_idx_ff (.clk(clk), .r(reset), .d(next_note_index), .q(note_index));
    dffr #(6) wait_cnt_ff (.clk(clk), .r(reset), .d(next_wait_counter), .q(wait_counter));
    dffr #(2) voice_ff (.clk(clk), .r(reset), .d(next_next_voice), .q(next_voice_q));

    // --- ROM Interface ---
    wire [8:0] addr = {song, note_index};
    wire [15:0] rom_out;
    song_rom rom_inst (.clk(clk), .addr(addr), .dout(rom_out));

    // --- Parsing Logic ---
    wire is_wait_cmd = rom_out[15];
    wire [5:0] cmd_val = rom_out[14:9]; // Wait Dur or Note Val
    wire [5:0] cmd_dur = rom_out[8:3];  // Note Dur
    
    // End = Note Cmd (0) with Note=0, Dur=0
    wire is_end = (!is_wait_cmd && cmd_val == 6'd0 && cmd_dur == 6'd0);

    // --- Next State Logic ---
    always @(*) begin
        // Defaults
        next_state = state;
        next_note_index = note_index;
        next_wait_counter = wait_counter;
        next_next_voice = next_voice_q;
        done = 1'b0;

        load_note0 = 0; note0 = 0; duration0 = 0;
        load_note1 = 0; note1 = 0; duration1 = 0;
        load_note2 = 0; note2 = 0; duration2 = 0;

        case (state)
            S_IDLE: begin
                next_note_index = 0;
                next_next_voice = 0;
                if (play) next_state = S_READ;
            end

            S_READ:     next_state = S_WAIT_ROM;
            S_WAIT_ROM: next_state = S_PARSE;

            S_PARSE: begin
                if (!play) begin
                    next_state = S_PARSE;
                end else if (is_end) begin
                    next_state = S_DONE;
                end else if (is_wait_cmd) begin
                    // WAIT: Load duration from [14:9]
                    next_wait_counter = cmd_val;
                    next_state = S_WAIT_TIME;
                end else begin
                    // NOTE: Dispatch to current voice
                    case (next_voice_q)
                        2'd0: begin note0=cmd_val; duration0=cmd_dur; load_note0=1; end
                        2'd1: begin note1=cmd_val; duration1=cmd_dur; load_note1=1; end
                        2'd2: begin note2=cmd_val; duration2=cmd_dur; load_note2=1; end
                        default: begin note0=cmd_val; duration0=cmd_dur; load_note0=1; end
                    endcase
                    
                    // Round Robin
                    next_next_voice = (next_voice_q == 2'd2) ? 2'd0 : next_voice_q + 1;
                    
                    // LOOP: Immediately read next address
                    next_note_index = note_index + 1;
                    next_state = S_READ;
                end
            end

            S_WAIT_TIME: begin
                if (play && beat) begin
                    if (wait_counter <= 1) begin
                        // Done waiting, read next
                        next_note_index = note_index + 1;
                        next_state = S_READ;
                    end else begin
                        next_wait_counter = wait_counter - 1;
                    end
                end
            end

            S_DONE: begin
                done = 1'b1;
                next_state = S_IDLE;
            end
        endcase
    end
    
    assign song_done = done;

endmodule
