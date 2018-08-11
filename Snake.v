// Snake game modified for VGA1306
// Magnus Karlsson
// See http://www.instructables.com/id/Snake-on-an-FPGA-Verilog/ for info about the original project

module Snake(VGA_clk, VGA_R, VGA_G, VGA_B, VGA_hSync, VGA_vSync,
             left, right, up, down);
  input left, right, up, down;
  input VGA_clk; //25 MHz
  output VGA_R;
  output VGA_G;
  output VGA_B;
  output VGA_hSync, VGA_vSync;

  // How much the snake grows for each apple hit
  parameter SIZE_INCREASE = 1;

  wire [9:0] xCount; //x pixel
  wire [9:0] yCount; //y pixel

  wire displayArea; //is it in the active display area?
  reg [3:0] direction;
  assign direction[0] = left;
  assign direction[1] = right;
  assign direction[2] = up;
  assign direction[3] = down;
  reg game_over = 1'b1;
  reg apple, border;
  reg [4:0] size;
  reg [6:0] appleX = 40;
  reg [6:0] appleY = 10;
  reg [6:0] snakeX[0:31];
  reg [6:0] snakeY[0:31];
  reg [31:0] snakeBody;
  wire update;

  integer count;

  VGA_gen gen1(VGA_clk, xCount, yCount, displayArea, VGA_hSync, VGA_vSync);
  updateClk UPDATE(VGA_clk, update);

  always@(posedge VGA_clk) begin
    if (game_over) begin // reset
      // place the snake head at display center
      snakeX[0] <= 40;
      snakeY[0] <= 30;
      for(count = 1; count < 32; count = count + 1)
        begin
          // place the invisible snake parts outside the scanning area
          snakeX[count] <= 127;
          snakeY[count] <= 127;
        end
      size <= 1;
      game_over <= 0;
    end else if (~game_over) begin
      if (update) begin
        for(count = 1; count < 32; count = count + 1)
          begin
            if(size > count)
            begin
              snakeX[count] <= snakeX[count - 1];
              snakeY[count] <= snakeY[count - 1];
            end
          end
        case(direction)
          4'b1110: snakeY[0] <= (snakeY[0] - 1);
          4'b1101: snakeX[0] <= (snakeX[0] - 1);
          4'b1011: snakeY[0] <= (snakeY[0] + 1);
          4'b0111: snakeX[0] <= (snakeX[0] + 1);
        endcase
      end else begin
        // Detect if snake head hit the apple
        if ((snakeX[0] == appleX) && (snakeY[0] == appleY)) begin
          appleX <= xCount[5:0] + direction[2:0];
          appleY <= yCount[4:0] + direction;
          if (size < 32 - SIZE_INCREASE)
            size <= size + SIZE_INCREASE;
        end
        // Detect if snake head hit border
        else if ((snakeX[0] == 0) || (snakeX[0] == 79) || (snakeY[0] == 0) || (snakeY[0] == 59))
          game_over <= 1'b1;
        /* Detect if snake head hit the snake body
        else if (|snakeBody[31:1] && snakeBody[0])
          game_over <= 1'b1; */
      end
    end
  end

  // Detect if the VGA scanning is hitting the border
  always @(posedge VGA_clk)
  begin
    border <= ((xCount[9:3] == 0) || (xCount[9:3] == 79) || (yCount[9:3] == 0) || (yCount[9:3] == 59));
  end

  // Detect if the VGA scanning is hitting the apple
  always @(posedge VGA_clk)
  begin
    apple <= (xCount[9:3] == appleX) && (yCount[9:3] == appleY);
  end

  // Detect if the VGA scanning is hitting the snake head or snake body
  always@(posedge VGA_clk)
  begin
    for(count = 0; count < 32; count = count + 1)
      snakeBody[count] <= (xCount[9:3] == snakeX[count]) & (yCount[9:3] == snakeY[count]);
  end

  always@(posedge VGA_clk)
  begin
    VGA_R = (displayArea && (apple || game_over));
    VGA_G = (displayArea && (|snakeBody && ~game_over));
    VGA_B = (displayArea && (border && ~game_over));
  end

endmodule

//////////////////////////////////////////////////////////////////////////////////////////////////////

module VGA_gen(VGA_clk, xCount, yCount, displayArea, VGA_hSync, VGA_vSync);

  input VGA_clk;
  output reg [9:0]xCount, yCount;
  output reg displayArea;
  output VGA_hSync, VGA_vSync;

  reg p_hSync, p_vSync;

  integer porchHF = 640; //start of horizntal front porch
  integer syncH = 656;//start of horizontal sync
  integer porchHB = 752; //start of horizontal back porch
  integer maxH = 799; //total length of line.

  integer porchVF = 480; //start of vertical front porch
  integer syncV = 490; //start of vertical sync
  integer porchVB = 492; //start of vertical back porch
  integer maxV = 525; //total rows.

  always@(posedge VGA_clk)
  begin
    if(xCount == maxH)
      xCount <= 0;
    else
      xCount <= xCount + 1;
  end
  always@(posedge VGA_clk)
  begin
    if(xCount == maxH)
    begin
      if(yCount == maxV)
        yCount <= 0;
      else
      yCount <= yCount + 1;
    end
  end

  always@(posedge VGA_clk)
  begin
    displayArea <= ((xCount < porchHF) && (yCount < porchVF));
  end

  always@(posedge VGA_clk)
  begin
    p_hSync <= ((xCount >= syncH) && (xCount < porchHB));
    p_vSync <= ((yCount >= syncV) && (yCount < porchVB));
  end

  assign VGA_vSync = ~p_vSync;
  assign VGA_hSync = ~p_hSync;
endmodule

//////////////////////////////////////////////////////////////////////////////////////////////////////

module updateClk(VGA_clk, update);
  input VGA_clk;
  output reg update;
  reg [21:0] count;

  always@(posedge VGA_clk)
  begin
    if(count == 1777777) begin
      update <= 1'b1;
      count <= 22'b0;
    end else begin
      update <= 1'b0;
      count <= count + 1'b1;
    end
  end
endmodule

//////////////////////////////////////////////////////////////////////////////////////////////////////