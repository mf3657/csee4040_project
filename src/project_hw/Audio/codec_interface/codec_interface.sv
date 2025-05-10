/******************************************************************************
 * Original file written by Scott Hauck for ECE271 at UW, Winter 2021         *
 ******************************************************************************/

/*
This audio driver module provides a simple interface with the DE1 SoC's
audio CODEC. The module is essentially a wrapper for a driver provided
by Altera. The purpose of the wrapper is to make implementation more
straightforward for users of the driver.

CLOCK_50 should be connected to the 50MHz system clock
reset should be connected to the system reset
dac_left and dac_right are 24-bit audio data samples provided by the
	user of the driver which go to the digital-to-analog converter of
	the CODEC.
adc_left and adc_right are 24-bit audio data samples provided by the
	driver which come from the analog-to-digital converter of the CODEC.
advance is used to signal a new sample of audio data. Advance 
	transitions on rising edges of CLOCK_50 and will remain low most of
	the time, periodically going high for one clock cycle. Advance
	notifies the user of the driver that there is valid data available
	on adc_left and adc_right until the next rising edge of the clock,
	and that valid data must be provided on dac_left and dac_right by
	the next rising edge of the clock. Advance pulses will be
	approximately evenly spaced at 48kHz.
FPGA_I2C_SCLK, FPGA_I2C_SDAT, AUD_XCK, AUD_DACLRCK, AUD_ADCLRCK,
	AUD_BCLK, AUD_ADCDAT, and AUD_DACDAT are external connections from
	the FPGA which go to the CODEC. These should be wired directly to
	ports on the top level module.
	
Timing diagram:
              __    __    __
CLOCK_50   __|  |__|  |__|  |__
                    __
advance    ________|  |________
                    __
dac_l/r    --------|__|--------
                    __
adc_l/r    --------|__|--------

Audio data is represented as PCM samples. Each sample is a 24 bit
unsigned integer. The sampling rate is 48kHz.
http://en.wikipedia.org/wiki/Pulse-code_modulation
*/

`timescale 1 ps / 1 ps

// synthesis translate_off
//`define DOING_SIMULATION 1
// synthesis translate_on

module codec_interface (CLOCK_50, reset, dac_left, dac_right, adc_left, adc_right, advance, FPGA_I2C_SCLK, FPGA_I2C_SDAT, AUD_XCK, AUD_DACLRCK, AUD_ADCLRCK, AUD_BCLK, AUD_ADCDAT, AUD_DACDAT);
	input CLOCK_50;
	input reset;
	// I2C Audio/Video config interface
	output FPGA_I2C_SCLK;
	inout FPGA_I2C_SDAT;
	// Audio CODEC
	output AUD_XCK;
	input AUD_DACLRCK, AUD_ADCLRCK, AUD_BCLK;
	input AUD_ADCDAT;
	output AUD_DACDAT;
	// Audio data
	input signed [23:0] dac_left, dac_right;
	output signed [23:0] adc_left, adc_right;
	output advance;
	
	// Local wires.
	wire read_ready, write_ready;
	reg write;
	wire read;
	
	// Registers are necessary for timing purposes as
	//     read_ready and write_ready go high for multiple clock cycles
	reg w1, w2;
	
	assign read = write;
	assign advance = write;

	always @(posedge CLOCK_50) begin
		if (reset) begin
			w1 <= 0;
			w2 <= 0;
			write <= 0;
		end else begin
			w1 <= write_ready & read_ready & !w2;
			w2 <= w1;
			write <= w1 & !w2;
		end
	end
	
	wire locked;
	
	// Don't use PLL for simulation
	`ifdef DOING_SIMULATION
		reg AUD_XCK;
		initial AUD_XCK = 0; 
		always begin 
			#(40690); 
			AUD_XCK = ~AUD_XCK; 
		end
	`else
		// PLL produces clock at correct frequency for CODEC
		xck_generator xck_source (.refclk(CLOCK_50),.rst(reset),.outclk_0(AUD_XCK), .locked(locked));
	`endif
	
	
/////////////////////////////////////////////////////////////////////////////////
// Audio CODEC interface. 
//
// The interface consists of the following wires:
// read_ready, write_ready - CODEC ready for read/write operation 
// readdata_left, readdata_right - left and right channel data from the CODEC
// read - send data from the CODEC (both channels)
// writedata_left, writedata_right - left and right channel data to the CODEC
// write - send data to the CODEC (both channels)
// AUD_* - should connect to top-level entity I/O of the same name.
//         These signals go directly to the Audio CODEC
// I2C_* - should connect to top-level entity I/O of the same name.
//         These signals go directly to the Audio/Video Config module
/////////////////////////////////////////////////////////////////////////////////

	audio_and_video_config cfg(
		// Inputs
		CLOCK_50,
		reset,

		// Bidirectionals
		FPGA_I2C_SDAT,
		FPGA_I2C_SCLK
	);

	audio_codec codec(
		// Inputs
		CLOCK_50,
		reset,

		read,	write,
		dac_left, dac_right,

		AUD_ADCDAT,

		// Bidirectionals
		AUD_BCLK,
		AUD_ADCLRCK,
		AUD_DACLRCK,

		// Outputs
		read_ready, write_ready,
		adc_left, adc_right,
		AUD_DACDAT
	);
endmodule


