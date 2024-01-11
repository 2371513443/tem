module seg_driver(
	input                       Clk     , //system clock 50MHz
	input                       Rst_n   , //reset, low valid
	
	input              [05:00]	point  	, //决定小数点是否点亮，低有效
	input              [23:00]	data_in , //默认以十进制数据输入
	input                       sign    ,
	output    reg      [05:00]	dig_sel , //
	output    reg      [07:00]	dig_seg   //
);
//Parameter Declarations
	parameter MAX_1MS = 50_000;

	localparam //段码显示参数
		SYB_0 = 8'b1100_0000,
		SYB_1 = 8'b1111_1001,
		SYB_2 = 8'b1010_0100,
		SYB_3 = 8'b1011_0000,
		SYB_4 = 8'b1001_1001,
		SYB_5 = 8'b1001_0010,
		SYB_6 = 8'b1000_0010,
		SYB_7 = 8'b1111_1000,
		SYB_8 = 8'b1000_0000,
		SYB_9 = 8'b1001_0000,
		SYB_A = 8'b1000_1000,
		SYB_B = 8'b1000_0011,
		SYB_C = 8'b1100_0110,
		SYB_D = 8'b1010_0001,
		SYB_E = 8'b1000_0110,
		SYB_F = 8'b1000_1110;

//Internal wire/reg declarations
	reg          [15:00]    cnt_1ms     ; //Counter 控制位选切换定时器
	wire                    add_cnt_1ms ; //Counter Enable
	wire                    end_cnt_1ms ; //Counter Reset 

	reg      	[03:00]		data_tmp 	; //
	reg 					dot 		; //小数点

//Logic Description
	always @(posedge Clk or negedge Rst_n)begin
		if(!Rst_n)begin  
			cnt_1ms <= 'd0; 
		end  
		else if(add_cnt_1ms)begin  
			if(end_cnt_1ms)begin  
				cnt_1ms <= 'd0; 
			end  
			else begin  
				cnt_1ms <= cnt_1ms + 1'b1; 
			end  
		end  
		else begin  
			cnt_1ms <= 'd0;  
		end  
	end 
		
	assign add_cnt_1ms = 1'b1; 
	assign end_cnt_1ms = add_cnt_1ms && cnt_1ms >= MAX_1MS - 1; 

	always @(posedge Clk or negedge Rst_n)begin 
		if(!Rst_n)begin
			dig_sel <= 6'b011_111;
		end  
		else if(end_cnt_1ms)begin
			dig_sel <= {dig_sel[0],dig_sel[5:1]}; //切换位选信号
		end  
		else begin
			dig_sel <= dig_sel;
		end
	end //always end
	
	always @(posedge Clk or negedge Rst_n)begin 
		if(!Rst_n)begin
			data_tmp <= 4'd0;
			dot      <= 1'b1;
		end  
		else begin
			case(dig_sel)
				6'b011_111:begin data_tmp <= data_in % 10 		  ;dot <= point[0] ;end //个位
				6'b101_111:begin data_tmp <= data_in / 10 % 10 	  ;dot <= point[1] ;end //十位
				6'b110_111:begin data_tmp <= data_in / 100 % 10   ;dot <= point[2] ;end //百位
				6'b111_011:begin data_tmp <= data_in / 1000 % 10  ;dot <= point[3] ;end //千位
				6'b111_101:begin data_tmp <= data_in / 10000 % 10 ;dot <= point[4] ;end //万位
				6'b111_110:begin 
					if(sign==1)begin
					dot <= point[5] ;//十万
					data_tmp <= 10;
				    end 
				    else begin
					    dot <= point[5] ; //十万
					    data_tmp <= 11;
				    end
	                end
				default: ;
			endcase
		end
	end //always end
	
	always @(posedge Clk or negedge Rst_n)begin 
		if(!Rst_n)begin
			dig_seg <= SYB_0;
		end   
		else begin
			case(data_tmp)
				0:dig_seg <= {dot,SYB_0[6:0]};
				1:dig_seg <= {dot,SYB_1[6:0]};
				2:dig_seg <= {dot,SYB_2[6:0]};
				3:dig_seg <= {dot,SYB_3[6:0]};
				4:dig_seg <= {dot,SYB_4[6:0]};
				5:dig_seg <= {dot,SYB_5[6:0]};
				6:dig_seg <= {dot,SYB_6[6:0]};
				7:dig_seg <= {dot,SYB_7[6:0]};
				8:dig_seg <= {dot,SYB_8[6:0]};
				9:dig_seg <= {dot,SYB_9[6:0]};
				10:dig_seg <= {dot,7'b0111111};
				11:dig_seg <= {dot,7'b1111111};
				default: ;
			endcase
		end
	end //always end
	
endmodule 
