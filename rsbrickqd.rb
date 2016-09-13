#!/usr/bin/env ruby
require 'logging'
require 'hex_string'

class RSbrickQDCommand
	
	VALID_STOP_COMMANDS = [:brake, :freewheel, :fw] # fw = short for freewheel	
	
	# port value for either a motor stop command (see VALID_STOP_COMMANDS) or motor drive value percentage as a 0-100 w/ positive value for clockwise or negative for counter clockwise
	def self.port_command_hex_string(pv) 
		# https://social.sbrick.com/forums/topic/252/ble-quickdrive-characteristic/view/post_id/3258
		# 0000000x no power - brake shunt mode, x = don't care
		# 0000001x no power - freewheeling mode, x = don't care
		# xxxxxxxd various speeds in direction d
		# 1111111d full speed in direction d
		# FYI in forum post: d = 0 for CW and d = 1 for CCW
		if pv.is_a?(Symbol)
			raise "bad stop command '#{pv}' must be one of #{VALID_STOP_COMMANDS.join(',')}" unless VALID_STOP_COMMANDS.include?(pv)
			if pv == :brake
				return "01" # binary value: "01".to_i.to_s(2).rjust(8,"0") => "00000001"
			else
				# free wheel
				return "02" # binary value: "02".to_i.to_s(2).rjust(8,"0") => "00000010"
			end
		else
			raise "bad power_percent [#{pv}] absolute value must be between 0 and 100" unless pv.to_i.abs <= 100 and pv.to_i.abs >= 0
			binary_string = (255 * pv.to_i.abs / 100).to_s(2).rjust(8, '0')
			dir_bit = pv.to_i < 0 ? "1" : "0"
			binary_string.gsub!(/[0-1]$/, dir_bit) # replace the last bit with direction
			hex_string = binary_string.to_i(2).to_s(16).upcase.rjust(2, '0')
			Logging.logger[self].debug("motor power percent => #{pv}%, :hex => #{hex_string}, :binary string => #{binary_string} (last bit is direction)")
			return hex_string
		end
		
	end
	
end	

class RSbrick
	
	def initialize(bt_interface, bt_sbrick_addr) 
		@bt_interface, @bt_sbrick_addr = bt_interface, bt_sbrick_addr
		@firmware_specific_handle_drive = "0x001a"
		@firmware_specific_handle_qd = "0x001e" # TODO move this to config or use a bluetooth lib to determin
		# to get handle:
		# - go to doc: https://social.sbrick.com/wiki/view/pageId/11/slug/the-sbrick-ble-protocol
		# - get UUID for quick drive  e.g. (489a6ae0-c1ab-4c9c-bdb2-11d373c1b7fb)
		# - run command gatttool -b 00:07:80:D0:57:C3 -i hci0 --characteristics
		# - e.g. gatttool -b 00:07:80:D0:57:C3 -i hci0 --characteristics | grep 489a6ae0-c1ab-4c9c-bdb2-11d373c1b7fb
		# use "char value handle"  NOT ANY OF THE OTHER HANDLES
		
		
		@keep_alive_interval_in_seconds = 0.2 # TODO move to config / setter
		@max_keep_alive_in_seconds = 10
		@logger = Logging.logger[self]
		
	end

	def max_keep_alive_in_seconds=(max_keep_alive_in_seconds)
		@max_keep_alive_in_seconds = max_keep_alive_in_seconds
	end

	def led_test
		# 01=drive + 04=device 5 LED + 00=direction N/A + FF or 00 on/off
		# on = true
		# c="010400" + (on ? "ff" : "00")
		# doesn't seem to work in current firmware all I can get working is flasing
		bt_call_write(@firmware_specific_handle_drive,"010400FF")
	end

	# returns resets since last uptime
	def version
		s = bt_call_read("0x000A")
		v = s.to_byte_string
		@logger.info ("hw/fm = #{v}")
		return v
	end


	# returns resets since last uptime
	def resets
		i = four_byte_le_unsigned_to_i(bt_call_write_read(@firmware_specific_handle_drive,"28"))
		@logger.info ("#{i} resets since last firmware")
		return i
	end
	
	#
	# returns uptime as int.  Int is 1th of a second.  So 90 seconds = 900 uptime
	def uptime
		i = four_byte_le_unsigned_to_i(bt_call_write_read(@firmware_specific_handle_drive,"29"))
		@logger.info ("uptime = H:M:S #{Time.at(i/10).utc.strftime("%H:%M:%S")}")
		return i
	end	
	
	def temperature
		i = two_byte_le_unsigned_to_i(bt_call_write_read(@firmware_specific_handle_drive,"0F0E"))
		t = i * 0.008413396 - 160
		@logger.info ("temperature = #{t} celsius")
		return t
	end	
	
	def voltage
		i = two_byte_le_unsigned_to_i(bt_call_write_read(@firmware_specific_handle_drive,"0F00"))
		v = i * 0.000378603;
		@logger.info ("voltage = #{v}")
		return v
	end	
		
	# array of 4 values (an array of values that will be passed to RSbrickQDCommand.port_command_hex_string)
	def quick_drive(port_values)
		# TODO support custom quick drive setups 
		raise "must specify an array of 4 ports in order 00-03" unless port_values.is_a?(Array) and port_values.count == 4
		@last_qd_command = port_values.map {|x| RSbrickQDCommand.port_command_hex_string(x)}.join('')
		bt_call_write(@firmware_specific_handle_qd, @last_qd_command)
	end
	
	def reset_keep_alive
		@reset_keep_alive = true
	end
	
	def stop_keep_alive
		@stop_keep_alive = true
	end	
	
	def kill_keep_alive_thread!
		Thread.kill(@keep_alive_thread) if @keep_alive_thread
		@keep_alive_thread = nil
	end	
	
	def spawn_keep_alive_thread
		if @keep_alive_thread
			@logger.warn("already have thread... this is a bad use case?")
			kill_keep_alive_thread!
		end
		@reset_keep_alive = false
		@stop_keep_alive = false		
		@keep_alive_thread = Thread.new do
			n = 0
			while n <= @max_keep_alive_in_seconds and !@stop_keep_alive do
				if @reset_keep_alive
					@logger.debug("keep alive reset")
					n = 0
					@reset_keep_alive = false
				end
				n = n + @keep_alive_interval_in_seconds
				bt_call_write(@firmware_specific_handle_qd,@last_qd_command, true) if @last_qd_command	
				sleep @keep_alive_interval_in_seconds
			end
			@logger.info("keep alive timed out")
		end
	end	
	
	private


	def four_byte_le_unsigned_to_i(s)
		# to_byte_string from hex_string gem
		# basically we pack a hex string then unpack an unsigned 32 bit int little endian byte order
		# who would have thought creating a int would warrent adding a gim
		return s.to_byte_string.unpack("<I")[0] 
	end
	
	# same as four_byte_le_unsigned_to_i except we only have a 16 bit int (2 bytes)
	def two_byte_le_unsigned_to_i(s) 
		return s.to_byte_string.unpack("<S")[0] 
	end


	## TODO switch to open3 lib


	def bt_call_read(handle)
		command_str = "gatttool -b #{@bt_sbrick_addr} -i #{@bt_interface} --char-read --handle=#{handle}"
		@logger.debug("sbick command: #{command_str}")
		s = `#{command_str}`
		@logger.debug("shell result: #{s}")
		s = s.to_s.split("Characteristic value/descriptor: ").last
		@logger.debug("value read: #{s}")
		return s
	end


	def bt_call_write_read(handle, the_command)
		command_str = "gatttool -b #{@bt_sbrick_addr} -i #{@bt_interface} --char-write --handle=#{handle} --value=#{the_command}"
		command_str = command_str + "; sleep 0.01;"
		command_str = command_str + "gatttool -b #{@bt_sbrick_addr} -i #{@bt_interface} --char-read --handle=#{handle}"
		@logger.debug("sbick command: #{command_str}")
		s = `#{command_str}`
		@logger.debug("shell result: #{s}")
		s = s.to_s.split("Characteristic value/descriptor: ").last
		@logger.debug("value read: #{s}")
		return s
	end
	
	
	def bt_call_write(handle,the_command, is_keep_alive = false)
		command_str = "gatttool -b #{@bt_sbrick_addr} -i #{@bt_interface} --char-write --handle=#{handle} --value=#{the_command}"
		if is_keep_alive
			@logger.debug("keep alive: #{command_str}")
		else
			@reset_keep_alive = true
			@logger.debug("sbick command: #{command_str}")
		end
		`#{command_str}`
	end
end



puts "starting"

Logging.logger.root.appenders = Logging.appenders.stdout
Logging.logger.root.level = :debug

b = RSbrick.new("hci0","00:07:80:D0:57:C3")



b.version
b.uptime
b.resets
b.temperature
b.voltage
b.led_test

# b.quick_drive([100,-50,:fw,:brake])

# my_logger.info "starting keep alive"
# b.spawn_keep_alive_thread
# sleep 7
# b.quick_drive([100,-50,:fw,:brake])
# my_logger.info "starting dup keep alive"
# b.spawn_keep_alive_thread
# sleep 5
# my_logger.info "killing keep alive"
# b.kill_keep_alive_thread!
# sleep 5
# my_logger.info "stopping keep alive"
# b.stop_keep_alive
# sleep 5

# sleep 40
puts "all done"

