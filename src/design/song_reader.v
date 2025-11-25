module song_reader(
    input clk,
    input reset,
    input play,
    input [1:0] song,
    input note_done,
    output song_done,
    output [5:0] note,
    output [5:0] duration,
    output new_note
);

    localparam S_IDLE      = 3'd0,
               S_READ      = 3'd1,
               S_WAIT_ROM  = 3'd2,
               S_SEND_NOTE = 3'd3,
               S_WAIT_DONE = 3'd4;

    wire [2:0] state;
    reg [2:0] next_state;
    
    wire [4:0] current_note;
    reg [4:0] next_note;
    
    wire [6:0] addr;
    wire [11:0] rom_out;
    
    reg note_rdy;
    reg done;
    
    assign addr = {song, current_note};
    
    song_rom song1 (
        .clk(clk),
        .addr(addr),
        .dout(rom_out)
    );
    
    assign {note, duration} = rom_out;
    
    dffr #(3) romFF (
        .clk(clk),
        .r(reset),
        .d(next_state),
        .q(state)
    );
    
    dffr #(5) noteFF (
        .clk(clk),
        .r(reset),
        .d(next_note),
        .q(current_note)
    );
    
    always @(*) begin
        case (state) 
            S_IDLE: begin
                next_state = S_SEND_NOTE; 
                next_note = current_note;
                done = 0;
                note_rdy = 0;
            end 
            S_READ: begin
                next_note = current_note + 5'd1;
                next_state = S_WAIT_ROM;
                done = (current_note == 5'd31);
                note_rdy = 0;
            end
            S_WAIT_ROM: begin
                next_state = play ? S_SEND_NOTE : S_WAIT_ROM;
                next_note = current_note;
                done = 0;
                note_rdy = 0;
            end
            S_SEND_NOTE: begin
                next_state = S_WAIT_DONE;
                next_note = current_note;
                done = 0;
                note_rdy = 1;
            end
            S_WAIT_DONE: begin
                // If the loaded note has zero duration, skip waiting for note_done
                next_state = (duration == 6'd0) ? S_READ : (note_done ? S_READ : S_WAIT_DONE);
                next_note = current_note;
                done = 0;
                note_rdy = 0;
            end
            default: begin
                next_state = state;
                next_note = current_note;
                done = 0;
                note_rdy = 0;
            end
       endcase
  end 
  
  assign new_note = note_rdy;
  assign song_done = done;
            
endmodule 
