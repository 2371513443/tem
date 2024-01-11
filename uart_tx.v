
module uart_tx(
   input    wire               sys_clk     , //时钟信号 50MHz
   input    wire               sys_rst_n   , //复位信号，低有效
   input    wire               start_flag_x  , //数据有效使能信号
   input    wire   [16:0]      baud_rate   , 
   input    wire   [7 :0]      data        , //数据
   output                      over_flag   ,
   output   reg                tx    
);
//参数定义
parameter TIME_1S = 26'd5000_0000;
parameter START   = 2'b01        ,
          SEND    = 2'b10        ;
//信号定义
wire [12:0] bit_time  ; 
wire [10:0] rx_data;
reg  [1:0]  state_c   ;
reg  [1:0]  state_n   ;
reg  [12:0] cnt_bit   ;
reg  [3:0]  bit_num   ;
reg         parity_bit;
//逻辑组成
assign bit_time=(TIME_1S/baud_rate)-1; // 计算每个位的时间
assign rx_data = {1'b1,parity_bit,data, 1'b0}; // 添加校验位
always @(posedge sys_clk or negedge sys_rst_n) begin
   if(!sys_rst_n)begin
      state_c <= START; // 复位时将当前状态设为START
   end
   else begin
      state_c <= state_n; // 正常工作状态下，当前状态更新为下一个状态
   end
end

always @(*) begin
   case (state_c)
      START:begin
         if(start_flag_x==1)begin
            state_n = SEND; // 当前状态为START时，如果收到start_flag_x信号，则下一个状态为SEND
         end
         else begin
            state_n = START; // 如果未收到start_flag_x信号，则保持当前状态为START
         end
      end
      SEND :begin
         if(cnt_bit==bit_time&&bit_num==10)begin
            state_n = START; // 当前状态为SEND时，如果达到指定的bit_time并且bit_num为9，则下一个状态为START
         end
         else begin
            state_n = SEND; // 其他情况下，下一个状态为SEND
         end
      end
      default: state_n = START; // 默认情况下，下一个状态为START
   endcase
end
always @(posedge sys_clk or negedge sys_rst_n) begin
   if (!sys_rst_n) begin
      parity_bit <= 1'b0; // 复位时将校验位parity_bit设置为逻辑低电平
   end
   else begin
      case (state_c)
         START: parity_bit <= 1'b0; // 当前状态为START时，校验位parity_bit设置为逻辑低电平
         SEND: begin
            if (cnt_bit == bit_time && bit_num == 8) begin
               if (data[0] ^ data[1] ^ data[2] ^ data[3] ^ data[4] ^ data[5] ^ data[6] ^ data[7]) begin
                  parity_bit <= 1'b0; // 奇校验
               end
               else begin
                  parity_bit <= 1'b1; // 偶校验
               end
            end
            else begin
               parity_bit <= parity_bit;
            end
         end
         default: parity_bit <= 1'b0; // 默认情况下，校验位parity_bit设置为逻辑低电平
      endcase
   end
end
always @(posedge sys_clk or negedge sys_rst_n) begin
   if(!sys_rst_n)begin
      cnt_bit <= 13'b0; // 复位时将计数器cnt_bit清零
   end
   else if(cnt_bit == bit_time&&state_c==SEND)begin
      cnt_bit <= 13'b0; // 当前状态为SEND时，如果计数器达到bit_time，则将计数器cnt_bit清零
   end
   else if(state_c==SEND)begin
      cnt_bit <= cnt_bit + 1'b1; // 当前状态为SEND时，计数器cnt_bit递增
   end
   else begin
      cnt_bit <= 13'b0; // 其他情况下，计数器cnt_bit清零
   end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
   if(!sys_rst_n)begin
      bit_num <= 1'b0; // 复位时将位号bit_num清零
   end
   else if(state_c==SEND)begin
      if(cnt_bit==bit_time)begin
         if(bit_num==10)begin
            bit_num <= 1'b0; // 当前状态为SEND时，如果计数器cnt_bit达到bit_time，并且位号bit_num为9，则将位号bit_num清零
         end
         else begin
            bit_num <= bit_num + 1'b1; // 其他情况下，位号bit_num递增
         end
      end
      else begin
         bit_num <= bit_num; // 其他情况下，保持位号bit_num不变
      end
   end
   else begin
      bit_num <= 1'b0; // 其他情况下，位号bit_num清零
   end
end

always @(*) begin
   if(!sys_rst_n)begin
      tx = 1'b1; // 复位时将输出信号tx设置为逻辑高电平
   end
   else begin
      case (state_c)
         START:tx = 1'b1; // 当前状态为START时，输出信号tx设置为逻辑高电平
         SEND :tx = rx_data[bit_num]; // 当前状态为SEND时，输出信号tx根据位号bit_num从tx_data中获取信号
         default:tx = 1'b1; // 默认情况下，输出信号tx设置为逻辑高电平
      endcase
   end
end
reg flag_send_data;
always @(posedge sys_clk or negedge sys_rst_n) begin
      if(!sys_rst_n) begin
         flag_send_data <= 0;
      end
      else if(start_flag_x) begin
         flag_send_data <= 1;
      end
      else if(cnt_bit==bit_time&&bit_num==10) begin
         flag_send_data <= 0;
      end
      else begin
         flag_send_data <= flag_send_data;
      end
   end
assign over_flag = ~flag_send_data  ;
endmodule


