module MAZE(
    // input
    input clk,
    input rst_n,
	input in_valid,
	input [1:0] in,

    // output
    output reg out_valid,
    output reg [1:0] out
);
// --------------------------------------------------------------
// Reg & Wire
// --------------------------------------------------------------

reg state, next_state;

parameter STATE_IDLE = 1'b0;
parameter STATE_WALK = 1'b1;
parameter RIGHT = 2'd0;
parameter DOWN = 2'd1;
parameter LEFT = 2'd2;
parameter UP = 2'd3;

reg[1:0] next_move;
reg[1:0] direction;
reg[1:0] read_data_right;
reg[1:0] read_data_down;
reg[1:0] read_data_left;
reg[1:0] read_data_up;
reg[1:0] maze[16:0][16:0];
reg[4:0] count_x, count_y;
reg[4:0] index_x, index_y;
reg sword;
reg right_can_go;
reg down_can_go;
reg left_can_go;
reg up_can_go;
// --------------------------------------------------------------
// Memory
// --------------------------------------------------------------
always @(posedge clk) begin
    if(in_valid)
        maze[count_x][count_y] <= in;
end
always @(*) begin
    read_data_right = maze[index_x + 1'b1][index_y];
    read_data_down = maze[index_x][index_y + 1'b1];
    read_data_left = maze[index_x - 1'b1][index_y];
    read_data_up = maze[index_x][index_y - 1'b1];
end
always @(posedge clk) begin
    if(in_valid)
        sword <= 1'b0;
    else if(maze[index_x][index_y][1])
        sword <= 1'b1;
    else
        sword <= sword;
end

// --------------------------------------------------------------
// CHOOSE PATH
// --------------------------------------------------------------
always @(*) begin
    if(index_x[4])
        right_can_go = 1'b0;
    else if(read_data_right == 2'd1)
        right_can_go = 1'b0;
    else if(read_data_right == 2'd3 && !sword && !maze[index_x][index_y][1])
        right_can_go = 1'b0;
    else
        right_can_go = 1'b1;
end
always @(*) begin
    if(index_y[4])
        down_can_go = 1'b0;
    else if(read_data_down == 2'd1)
        down_can_go = 1'b0;
    else if(read_data_down == 2'd3 && !sword && !maze[index_x][index_y][1])
        down_can_go = 1'b0;
    else
        down_can_go = 1'b1;
end
always @(*) begin
    if(index_x == 5'd0)
        left_can_go = 1'b0;
    else if(read_data_left == 2'd1)
        left_can_go = 1'b0;
    else if(read_data_left == 2'd3 && !sword && !maze[index_x][index_y][1])
        left_can_go = 1'b0;
    else
        left_can_go = 1'b1;
end
always @(*) begin
    if(index_y == 5'd0)
        up_can_go = 1'b0;
    else if(read_data_up == 2'd1)
        up_can_go = 1'b0;
    else if(read_data_up == 2'd3 && !sword && !maze[index_x][index_y][1])
        up_can_go = 1'b0;
    else
        up_can_go = 1'b1;
end
always @(*) begin
    case (direction)
        RIGHT:begin
            if(up_can_go)
                next_move = UP;
            else if(right_can_go)
                next_move = RIGHT;
            else if(down_can_go)
                next_move = DOWN;
            else
                next_move = LEFT;
        end
        DOWN:begin
            if(right_can_go)
                next_move = RIGHT;
            else if(down_can_go)
                next_move = DOWN;
            else if(left_can_go)
                next_move = LEFT;
            else
                next_move = UP;
        end
        LEFT:begin
            if(down_can_go)
                next_move = DOWN;
            else if(left_can_go)
                next_move = LEFT;
            else if(up_can_go)
                next_move = UP;
            else
                next_move = RIGHT;
        end
        UP:begin
            if(left_can_go)
                next_move = LEFT;
            else if(up_can_go)
                next_move = UP;
            else if(right_can_go)
                next_move = RIGHT;
            else
                next_move = DOWN;
        end
        default: next_move = RIGHT;
    endcase
end
always @(posedge clk) begin
    if(in_valid)
        direction <= RIGHT;
    else
        direction <= next_move;
end

// --------------------------------------------------------------
// COUNT & INDEX
// --------------------------------------------------------------

always @(posedge clk) begin
    if(!in_valid)
        count_x <= 5'd0;
    else if(count_x[4])
        count_x <= 5'd0;
    else if(in_valid)
        count_x <= count_x + 1'b1;
    else
        count_x <= count_x;
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        count_y <= 5'd0;
    else if(!in_valid)
        count_y <= 5'd0;
    else if(count_x[4])
        count_y <= count_y + 1'b1;
    else
        count_y <= count_y;
end
always @(posedge clk) begin
    if(in_valid)
        index_x <= 5'd0;
    else begin
        if(next_move == RIGHT)
            index_x <= index_x + 1'b1;
        else if(next_move == LEFT)
            index_x <= index_x - 1'b1;
        else
            index_x <= index_x;
    end
end
always @(posedge clk) begin
    if(in_valid)
        index_y <= 5'd0;
    else begin
        if(next_move == DOWN)
            index_y <= index_y + 1'b1;
        else if(next_move == UP)
            index_y <= index_y - 1'b1;
        else
            index_y <= index_y;
    end
end

// --------------------------------------------------------------
// FSM
// --------------------------------------------------------------

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        state <= STATE_IDLE;
    else
        state <= next_state;
end
always @(*) begin
    case (state)
        STATE_IDLE: begin
            if (count_x[4] && count_y[4])
                next_state = STATE_WALK;
            else
                next_state = STATE_IDLE;
        end
        STATE_WALK: begin
            if (index_x[4] && index_y[4])
                next_state = STATE_IDLE;
            else
                next_state = STATE_WALK;
        end
        default: next_state = STATE_IDLE;
    endcase
end
always @(*) begin
    if(state == STATE_IDLE)
        out_valid = 1'b0;
    else
        out_valid = !(index_x[4] && index_y[4]);
end
always @(*) begin
    if(!out_valid)
        out = 2'd0;
    else
        out = next_move;
end
endmodule