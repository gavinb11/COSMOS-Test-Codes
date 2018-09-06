
require 'cosmos/interfaces/protocols/protocol'

module Cosmos
    class Ax25ReadProtocol < KissReadProtocol
        AX25_CONTROL = 0x03
        AX25_PID = 0xF0
        ADDR_LENGTH = 7 #each address in the AX.25 header is 7 octets long (7 bytes -> 6 callsign octets + 1 SSID octet)
        BYTE_END_INDEX = 6 #index of last byte for an address (7 bytes, index of last byte is 6)
        MAX_ADDRS = 10

        #GIVES: # of addresses - addresses - payload
        def read_data(data_incoming)
            #SEND TO READ PROTOCOL ABOVE
            #IF NO KISS: return super(data_incoming) if (data_incoming.length <= 0)
            #IF NO KISS: data_in = data_incoming
            data_in = super(data_incoming) #IF KISS
            data = data_in.bytes() #convert data received into bytes format
            #PROCESS DATA
            #AX.25 PROTOCOL
            ax25_frame = data #change of variable for data: data -> ax25_frame
            if ax25_frame.length() >= 14 #at least 2 addresses (destination and source), each 7 bytes for a total of at least 14 bytes
                #AX.25 - addresses
                ax25_addrs = []
                addr_count = 0 #number of addresses counter in AX.25 header
                eoa_val = 0 #bit value at end of individual address: 0 if no more addresses, 1 if more
                while eoa_val == 0
                    addr_count += 1
                    addr_current = []
                    iter_current = 0
                    eoa_val = ax25_frame[BYTE_END_INDEX] & 0x01 #change eoa_val to match bit at end of current address
                    addr_bytes = ax25_frame[0...ADDR_LENGTH] #bytes that make up current address (7 bytes: 6 callsign + 1 SSID)
                    ax25_frame = ax25_frame[ADDR_LENGTH..-1] #remove bytes of current address from remaining data
                    ssid_byte = addr_bytes.delete_at(-1) #last byte in current address is SSID byte, remove it from remaining data
                    ssid_byte = (ssid_byte >> 1) #SSID byte format: left shifted by one, 0 1 1 S S I D eoa
                    addr_bytes.each { |byte_i| addr_current.push((byte_i >> 1) & 0x7F) } #callsign byte format: left shifted by one, X X X X X X X 0
                    addr_current.push(ssid_byte)
                    addr_current.each { |byte_i| ax25_addrs.push(byte_i) }
                end
                #AX.25 - control & PID
                frame_length_mid = ax25_frame.length()
                case frame_length_mid
                when 0 then puts "AX.25 READ ERROR: Packet insufficient length - No Control byte"
                when 1 then puts "AX.25 READ ERROR: Packet insufficient length - No PID byte"
                when 2 then puts "AX.25 READ ERROR: Packet insufficient length - No Payload"
                else
                    ax25_control = ax25_frame.delete_at(0) #control byte, remove it from reamining data
                    puts "AX.25 READ ERROR: AX.25 Control Byte - Not #{AX25_CONTROL}" if ax25_control != AX25_CONTROL
                    ax25_pid = ax25_frame.delete_at(0) #protocol identifier byte, remove it from remaining data
                    puts "AX.25 READ ERROR: AX.25 PID Byte - Not #{AX25_PID}" if ax25_pid != AX25_PID
                    #AX. 25 - payload
                    ax25_payload = []
                    ax25_frame.each { |byte| ax25_payload.push(byte) } #remaining data is payload
                end
            else
                puts "AX.25 READ ERROR: Packet insufficient length - Address field length is #{ax25_frame.length()} (< 14 bytes)"
            end
            packet_recv = []
            ax25_addrs.each { |byte_i| packet_recv.push(byte_i) }
            for i in 1..(MAX_ADDRS - 2)
                for i in 1..ADDR_LENGTH
                    packet_recv.push(" ".bytes[0])
                end
            end
            ax25_payload.each { |byte_i| packet_recv.push(byte_i) }
            data_recv = [addr_count].pack("C") + packet_recv.pack("C*")
            return data_recv
        end

    end
end
