module snake (input [0:0] CLOCK_27, input [1:0] KEY, input [0:0] SW,
				  output reg [3:0] VGA_R, VGA_G, VGA_B, output reg VGA_HS, VGA_VS, output [6:0] HEX0, HEX1, HEX2, HEX3
				  /*, output [9:0] LEDR, output [7:0] LEDG*/); 
				  
parameter FRONT_PORCH_A = 16;
parameter SYNC_PULSE_B  = 96;
parameter BACK_PORCH_C  = 48;
parameter ACTIVE_VIDEO_D= 640;
parameter CYCLES_LINE = FRONT_PORCH_A + SYNC_PULSE_B + BACK_PORCH_C + ACTIVE_VIDEO_D;

parameter V_FRONT_PORCH_A  = 10;
parameter V_SYNC_PULSE_B   = 2;
parameter V_BACK_PORCH_C   = 33;
parameter V_ACTIVE_VIDEO_D = 480;
parameter CYCLES_ROW = V_FRONT_PORCH_A + V_SYNC_PULSE_B + V_BACK_PORCH_C + V_ACTIVE_VIDEO_D;

parameter COLS = 8'd80;
parameter ROWS = 8'd60;
parameter BODYMAX = 50;


integer i;

wire VGA_CLK;
clock_25_2 u0( .clk_out_clk(VGA_CLK), .clk_res_reset(0), .clk_in_clk(CLOCK_27[0]) );
reg [31:0] tickCounter;
reg [31:0] ticks;
reg clkFrame;

reg [15:0] HS_count;
reg [15:0] VS_count;

wire [15:0] rndBig;
LFSR16 lfsr1(VGA_CLK, rndBig);
wire [7:0] rndHi;
wire [7:0] rndLo;
assign {rndHi, rndLo} = rndBig[15:0];

reg [7:0] xFood;
reg [7:0] yFood;
reg isFoodPlaced;
reg isDead;
reg [7:0] score;
led7 h3((score / 1000) % 10, HEX3); led7 h2((score / 100) % 10, HEX2); led7 h1((score / 10) % 10, HEX1); led7 h0(score % 10, HEX0);
//led7 h3(xFood/10, HEX3); led7 h2(xFood%10, HEX2); led7 h1(yFood/10, HEX1); led7 h0(yFood%10, HEX0);

reg [7:0] bodyX [BODYMAX-1:0];
reg [7:0] bodyY [BODYMAX-1:0];
reg [6:0] bodyLength;
reg [7:0] x;
reg [7:0] y;
reg [1:0] direction;
//assign LEDG[1:0]=direction;
//led7 h3(x/10, HEX3); led7 h2(x%10, HEX2); led7 h1(y/10, HEX1); led7 h0(y%10, HEX0);


//*Timer*************************************************************************
always @(posedge VGA_CLK) begin
	tickCounter <= tickCounter + 1;
	if( tickCounter==(32'd25_200_000 / (60+bodyLength)) ) 
	begin
		tickCounter <=0;
		clkFrame <= ~clkFrame;
		
		if(ticks==29)
			ticks<=0;
		else
			ticks <= ticks + 1;
	end
end

//*Logika************************************************************************
always @(posedge clkFrame) begin
	if(SW[0]==0) begin
		x <= (COLS/2'd2);
		y <= (ROWS/2'd2);
		isFoodPlaced = 0;
		score = 0;
		bodyLength = 1'b1;
		isDead <= 0;
	end
	
	if(SW[0] && !isDead) begin
		if(!isFoodPlaced) begin	
			xFood <= rndHi;
			yFood <= rndLo;
			isFoodPlaced = 1;
		end
		if(xFood>79) xFood <= rndHi;
		if(yFood>59) yFood <= rndLo;
		
		// eat food
		if(x==xFood && y==yFood) begin
			score = score + 1'b1;
			if(bodyLength<BODYMAX-1)
				bodyLength = bodyLength + 1'b1;
			isFoodPlaced = 0;
			bodyX[bodyLength-1] = x;
			bodyY[bodyLength-1] = y;
		end
		
		// is food inside body?
		i=0;
		while(i<bodyLength-2 && i<BODYMAX-1)
		begin
			if( bodyX[i] == xFood && bodyY[i] == yFood) begin
				xFood <= rndHi;
				yFood <= rndLo;
			end
			i = i + 1;
		end	
		
		// head move
		case(direction)
			0 : if(x==COLS-1) x <= 0;
				 else 			x <= x + 1'b1;
			1 : if(y==ROWS-1) y <= 0;
				 else 			y <= y + 1'b1;
			2 : if(x==0) 		x <= COLS - 1'b1;
				 else 	 		x <= x - 1'b1;
			3 : if(y==0) 		y <= ROWS - 1'b1;
				 else 			y <= y - 1'b1;
			default : ;
		endcase	
				
		// crash test
		i=0;
		while(i<bodyLength-1 && i<BODYMAX-1)
		begin
			if( bodyX[i] == x && bodyY[i] == y)
				isDead <= 1;
			i = i + 1;
		end		
		
		// body move
		i=0;
		while(i<bodyLength-1 && i<BODYMAX-1)
		begin
			bodyX[i] = bodyX[i+1];
			bodyY[i] = bodyY[i+1];
			i = i + 1;
		end
		bodyX[bodyLength-1] = x;
		bodyY[bodyLength-1] = y;
		

	end //if(SW[0] && !isDead)
end


//*Przyciski*********************************************************************
reg [1:0] det_edge;
wire sig_edge;
assign sig_edge = (det_edge == 2'b10);

reg [1:0] det_edge1;
wire sig_edge1;
assign sig_edge1 = (det_edge1 == 2'b10);

always @(posedge VGA_CLK) begin
	det_edge  <= {det_edge[0],  KEY[0]};
	det_edge1 <= {det_edge1[0], KEY[1]};
	if(sig_edge) begin
		if(direction==3) direction<=0;
		else direction<= direction + 1'b1;
	end 
	else if(sig_edge1) begin
		if(direction>3) direction<=3;
		else direction<= direction - 1'b1;
	end 
	else if(!SW[0])
		direction <= 0;
end
 
//*Wyświetlanie*****************************************************************
always @(posedge VGA_CLK)
if(HS_count<640 && VS_count<480) begin
	if(SW[0]) begin
		VGA_R <= 4'b1000;
		VGA_G <= 4'b1010;
		VGA_B <= 4'b0110;
		
		/*
		if(HS_count==x && VS_count==y) begin
			VGA_R <= 4'b0000;
			VGA_G <= 4'b0000;
			VGA_B <= 4'b1111;
		end
		*/
		i=0;
		while(i<BODYMAX && i<bodyLength) begin
			if(bodyX[i]==HS_count/8 && bodyY[i]==VS_count/8) begin
				VGA_R <= 4'b0000;
				VGA_G <= 4'b0000;
				VGA_B <= 4'b0000;
			end
			i=i+1;
		end
				
		if(xFood==HS_count/8 && yFood==VS_count/8) begin
			if(ticks<22) begin
				VGA_R <= 4'b0000;
				VGA_G <= 4'b0000;
				VGA_B <= 4'b0000;
			end
		end
		
	end else begin
		VGA_R <= (VS_count-ticks+5);
		VGA_G <= (VS_count-ticks+10);
		VGA_B <= (VS_count-ticks);
	end
end else begin
	VGA_R <= 4'b0000;
	VGA_G <= 4'b0000;
	VGA_B <= 4'b0000;
end


//*Sync************************************************************************************
always @(posedge VGA_CLK) // HSYNC
begin
	if(HS_count < CYCLES_LINE)
		HS_count <= HS_count + 1'b1;
	else
		HS_count <= 0;
	
	if(HS_count > ACTIVE_VIDEO_D + FRONT_PORCH_A && HS_count < CYCLES_LINE - BACK_PORCH_C)
		VGA_HS <= 0;
	else
		VGA_HS <= 1;
end 
 
always @(posedge VGA_CLK) // VSYNC
if(HS_count==CYCLES_LINE-1) 
begin 
	if(VS_count < CYCLES_ROW)
		VS_count <= VS_count + 1'b1;
	else
		VS_count <= 0;
		
	if(VS_count > V_ACTIVE_VIDEO_D+V_FRONT_PORCH_A && VS_count < CYCLES_ROW - V_BACK_PORCH_C)
		VGA_VS <= 0;
	else
		VGA_VS <= 1;
end

endmodule


//*Random***********************************************************************
module LFSR16(
  input clk,
  output reg [15:0] LFSR
);

always @(posedge clk)
begin
  LFSR[0] <= ~(LFSR[1] ^ LFSR[2] ^ LFSR[4] ^ LFSR[15]);
  LFSR[15:1] <= LFSR[14:0];
end
endmodule


//*LCD**************************************************************************
module led7(input [3:0] mod0,	output reg [6:0] led);
always begin
	case(mod0)	  //654_3210
		0 : led = 7'b100_0000;
		1 : led = 7'b111_1001;
		2 : led = 7'b010_0100;
		3 : led = 7'b011_0000;
		4 : led = 7'b001_1001;
		5 : led = 7'b001_0010;
		6 : led = 7'b000_0010;
		7 : led = 7'b111_1000;
		8 : led = 7'b000_0000;
		9 : led = 7'b001_0000;
		default : led = 7'b111_1111;
	endcase
end
endmodule
