/* This module sends and receives data to/from the DE1's audio and TV
 * peripherals' control registers. 
 *
 * Inputs:
 *   clk 					   - should be connected to a 50 MHz clock
 *   reset 					   - resets the module
 *   clear_ack 				- clears the ackowledgement signal
 *   clk_400KHz 			   - should be connected to a 400 KHz clock
 *   start_and_stop_en 		- bit to start or stop the enable signal
 *   change_output_bit_en 	- bit to enable changing the output
 *   send_start_bit 		   - bit to start recieving data
 *   send_stop_bit 			- bit to stop recieving data
 *   data_in 				   - data recieved from DE1 audio
 *   transfer_data 			- data to be transfered
 *   read_byte 				- data to be read
 *   num_bits_to_transfer 	- number of bits that are going to be transfered
 *
 * Bidirectional:
 *   i2c_sdata 				- I2C Data
 *
 * Outputs:
 *   i2c_sclk 				   - I2C Clock
 *   i2c_scen 				   - should connect to top-level entity I/O of the same name
 *   enable_clk			   - signal that enables the clock
 *   ack 					   - ackowledgement signal
 *   data_from_i2c 			- I2C Data
 *   transfer_complete 		- transfer complete signal
 */
module Altera_UP_I2C (
	clk,
	reset,
	clear_ack,
	clk_400KHz,
	start_and_stop_en,
	change_output_bit_en,
	send_start_bit,
	send_stop_bit,
	data_in,
	transfer_data,
	read_byte,
	num_bits_to_transfer,
	i2c_sdata,
	i2c_sclk,
	i2c_scen,
	enable_clk,
	ack,
	data_from_i2c,
	transfer_complete
);

	parameter I2C_BUS_MODE = 1'b0;

	input clk;
	input reset;
	input clear_ack;
	input clk_400KHz;
	input start_and_stop_en;
	input change_output_bit_en;
	input send_start_bit;
	input send_stop_bit;
	input [7:0]	data_in;
	input transfer_data;
	input read_byte;
	input [2:0]	num_bits_to_transfer;
	inout i2c_sdata;
	output i2c_sclk;
	output reg i2c_scen;
	output enable_clk;
	output reg ack;
	output reg [7:0] data_from_i2c;
	output transfer_complete;

	// states
	localparam	I2C_STATE_0_IDLE			= 3'h0,
				I2C_STATE_1_PRE_START		= 3'h1,
				I2C_STATE_2_START_BIT		= 3'h2,
				I2C_STATE_3_TRANSFER_BYTE	= 3'h3,
				I2C_STATE_4_TRANSFER_ACK	= 3'h4,
				I2C_STATE_5_STOP_BIT		= 3'h5,
				I2C_STATE_6_COMPLETE		= 3'h6;

	reg [2:0] current_bit;
	reg [7:0] current_byte;
	reg [2:0] ns_i2c_transceiver;
	reg [2:0] s_i2c_transceiver;

	always @(posedge clk)
	begin
		if (reset == 1'b1)
			s_i2c_transceiver <= I2C_STATE_0_IDLE;
		else
			s_i2c_transceiver <= ns_i2c_transceiver;
	end //always @(posedge clk)

	always @(*)
	begin
		// Defaults
		ns_i2c_transceiver = I2C_STATE_0_IDLE;

		case (s_i2c_transceiver)
		I2C_STATE_0_IDLE:
			begin
				if ((send_start_bit == 1'b1) && (clk_400KHz == 1'b0))
					ns_i2c_transceiver = I2C_STATE_1_PRE_START;
				else if (send_start_bit == 1'b1)
					ns_i2c_transceiver = I2C_STATE_2_START_BIT;
				else if (send_stop_bit == 1'b1)
					ns_i2c_transceiver = I2C_STATE_5_STOP_BIT;
				else if (transfer_data == 1'b1)
					ns_i2c_transceiver = I2C_STATE_3_TRANSFER_BYTE;
				else
					ns_i2c_transceiver = I2C_STATE_0_IDLE;
			end //I2C_STATE_0_IDLE
		I2C_STATE_1_PRE_START:
			begin
				if (start_and_stop_en == 1'b1)
					ns_i2c_transceiver = I2C_STATE_2_START_BIT;
				else
					ns_i2c_transceiver = I2C_STATE_1_PRE_START;
			end //I2C_STATE_1_PRE_START
		I2C_STATE_2_START_BIT:
			begin
				if (change_output_bit_en == 1'b1)
				begin
					if ((transfer_data == 1'b1) && (I2C_BUS_MODE == 1'b0))
						ns_i2c_transceiver = I2C_STATE_3_TRANSFER_BYTE;
					else
						ns_i2c_transceiver = I2C_STATE_6_COMPLETE;
				end //if (change_output_bit_en == 1'b1)
				else
					ns_i2c_transceiver = I2C_STATE_2_START_BIT;
			end //I2C_STATE_2_START_BIT
		I2C_STATE_3_TRANSFER_BYTE:
			begin
				if ((current_bit == 3'h0) && (change_output_bit_en == 1'b1))
				begin
					if ((I2C_BUS_MODE == 1'b0) || (num_bits_to_transfer == 3'h6))
						ns_i2c_transceiver = I2C_STATE_4_TRANSFER_ACK;
					else
						ns_i2c_transceiver = I2C_STATE_6_COMPLETE;
				end //if ((current_bit == 3'h0) && (change_output_bit_en == 1'b1))
				else
					ns_i2c_transceiver = I2C_STATE_3_TRANSFER_BYTE;
			end //I2C_STATE_3_TRANSFER_BYTE
		I2C_STATE_4_TRANSFER_ACK:
			begin
				if (change_output_bit_en == 1'b1)
					ns_i2c_transceiver = I2C_STATE_6_COMPLETE;
				else
					ns_i2c_transceiver = I2C_STATE_4_TRANSFER_ACK;
			end //I2C_STATE_4_TRANSFER_ACK
		I2C_STATE_5_STOP_BIT:
			begin
				if (start_and_stop_en == 1'b1)
					ns_i2c_transceiver = I2C_STATE_6_COMPLETE;
				else
					ns_i2c_transceiver = I2C_STATE_5_STOP_BIT;
			end //I2C_STATE_5_STOP_BIT
		I2C_STATE_6_COMPLETE:
			begin
				if (transfer_data == 1'b0)
					ns_i2c_transceiver = I2C_STATE_0_IDLE;
				else
					ns_i2c_transceiver = I2C_STATE_6_COMPLETE;
			end //I2C_STATE_6_COMPLETE
		default:
			begin
				ns_i2c_transceiver = I2C_STATE_0_IDLE;
			end //default
		endcase //case (s_i2c_transceiver)
	end //always @(*)


	always @(posedge clk)
	begin
		if (reset == 1'b1)
			i2c_scen <= 1'b1;
		else if (change_output_bit_en & (s_i2c_transceiver == I2C_STATE_2_START_BIT))
			i2c_scen <= 1'b0;
		else if (s_i2c_transceiver == I2C_STATE_5_STOP_BIT)
			i2c_scen <= 1'b1;
	end //always @(posedge clk)

	always @(posedge clk)
	begin
		if (reset == 1'b1)
			ack <= 1'b0;
		else if (clear_ack == 1'b1)
			ack <= 1'b0;
		else if (start_and_stop_en & (s_i2c_transceiver == I2C_STATE_4_TRANSFER_ACK))
			ack <= i2c_sdata ^ I2C_BUS_MODE;
	end //always @(posedge clk)

	always @(posedge clk)
	begin
		if (reset == 1'b1)
			data_from_i2c <= 8'h00;
		else if (start_and_stop_en & (s_i2c_transceiver == I2C_STATE_3_TRANSFER_BYTE))
			data_from_i2c <= {data_from_i2c[6:0], i2c_sdata};
	end //always @(posedge clk)


	always @(posedge clk)
	begin
		if (reset == 1'b1)
			current_bit	<= 3'h0;
		else if ((s_i2c_transceiver == I2C_STATE_3_TRANSFER_BYTE) && (change_output_bit_en == 1'b1))
			current_bit <= current_bit - 3'h1;
		else if (s_i2c_transceiver != I2C_STATE_3_TRANSFER_BYTE)
			current_bit <= num_bits_to_transfer;
	end //always @(posedge clk)

	always @(posedge clk)
	begin
		if (reset == 1'b1)
			current_byte <= 8'h00;
		else if ((s_i2c_transceiver == I2C_STATE_0_IDLE) || 
				(s_i2c_transceiver == I2C_STATE_2_START_BIT))
				current_byte <= data_in;
	end //always @(posedge clk)

	assign i2c_sclk	= (I2C_BUS_MODE == 1'b0) ? 
					clk_400KHz :
					((s_i2c_transceiver == I2C_STATE_3_TRANSFER_BYTE) |
					(s_i2c_transceiver == I2C_STATE_4_TRANSFER_ACK)) ? clk_400KHz : 1'b0;

	assign i2c_sdata = 
		(s_i2c_transceiver == I2C_STATE_2_START_BIT) ? 1'b0 :
		(s_i2c_transceiver == I2C_STATE_5_STOP_BIT) ? 1'b0 :
		((s_i2c_transceiver == I2C_STATE_4_TRANSFER_ACK) & read_byte) ? 1'b0 :
		((s_i2c_transceiver == I2C_STATE_3_TRANSFER_BYTE) & ~read_byte) ? current_byte[current_bit] : 1'bz;

	assign enable_clk	= ~(s_i2c_transceiver == I2C_STATE_0_IDLE) &&
						~(s_i2c_transceiver == I2C_STATE_6_COMPLETE);

	assign transfer_complete = (s_i2c_transceiver == I2C_STATE_6_COMPLETE) ? 1'b1 : 1'b0;

endmodule //Altera_UP_I2C

