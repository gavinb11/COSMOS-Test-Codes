#READING AND WRITING CLASS FOR CLIENT SAT

class KissAxProt
    FEND = "\xC0".bytes[0]
    FESC = "\xDB".bytes[0]
    TFEND = "\xDC".bytes[0]
    TFESC = "\xDD".bytes[0]
    KISS_COMMAND = "\x00".bytes[0]
    AX25_CONTROL = "\x03".bytes[0]
    AX25_PID = "\xF0".bytes[0]

    FEND_ARR = "\xC0".bytes
    FESC_ARR = "\xDB".bytes
    TFEND_ARR = "\xDC".bytes
    TFESC_ARR = "\xDD".bytes
    KISS_COMMAND_ARR = "\x00".bytes
    AX25_CONTROL_ARR = "\x03".bytes
    AX25_PID_ARR = "\xF0".bytes
    
    SAT_CALL = "SAT123".bytes.to_a
    SAT_SSID = "0".bytes.to_a
    SAT_ADDR = "SAT1230".bytes.to_a
    GST_CALL = "GST123".bytes.to_a
    GST_SSID = "2".bytes.to_a
    GST_ADDR = "GST1232".bytes.to_a

    ADDR_LENGTH = 7 #each address in the AX.25 header is 7 octets long (7 bytes -> 6 callsign octets + 1 SSID octet)
    BYTE_END_INDEX = 6 #index of last byte for an address (7 bytes, index of last byte is 6)

    #NEED REPLACE_KISS_W

    def left_shifter(data_bytes, special)
        data_bytes1 = data_bytes
        data_bytes1 = data_bytes1.collect {|byte_i| byte_i << 1}
        if special != 0
            data_bytes1[-1] = data_bytes1[-1] | 0x01
        end
        return data_bytes1
    end

    def replace_kiss_r(type_replace, data_repl)
        if type_replace == "FESC" #FESC + TFESC -> FESC
            byte_curr = FESC + TFESC
            byte_repl = FESC
        elsif type_replace == "FEND" #FESC + TFEND -> FEND
            byte_curr = FESC + TFEND
            byte_repl = FEND
        else
            puts "Error: Invalid Replacement Type (valid replacement types: 'FESC' or 'FEND' (strings)"
        end
        check_r = data_repl.include?(byte_curr) #check if byte stream contains byte_curr
        while check_r == true #keep replacing byte_curr as many time as that sequence of bytes appears in data stream
            index_r = data_repl.index(byte_curr) #obtain index of byte_curr
            data_repl = data_repl[0..(index_r - 1)] + byte_repl + data_repl[(index_r + 2)..-1] #replace byte_curr with byte_repl
            check_r = data_repl.include?(byte_curr) #check if byte stream contains byte_curr
        end
        return data_repl
    end

    def write_data_packet(payload)
        @payload = payload
        dest_call_hex = left_shifter(GST_CALL, 0)
        dest_ssid_hex = left_shifter(GST_SSID, 0)
        src_call_hex = left_shifter(SAT_CALL, 0)
        src_ssid_hex = left_shifter(SAT_SSID, 1)
        #puts dest_call_hex, dest_ssid_hex, src_call_hex, src_ssid_hex
        addresses = dest_call_hex + dest_ssid_hex + src_call_hex + src_ssid_hex
        ax25_frame = addresses + AX25_CONTROL_ARR + AX25_PID_ARR + @payload
        kiss_frame = FEND_ARR + KISS_COMMAND_ARR + ax25_frame + FEND_ARR
        kiss_frame_st = kiss_frame.pack("C*")
        return kiss_frame_st
    end

    #GIVES: # of addresses - addresses - payload
    def read_data_packet(packet_incoming)
        data = packet_incoming.bytes() #convert data received into bytes format
        #PROCESS DATA
        #KISS PROTOCOL
        if data[0] == FEND && data[-1] == FEND
            #KISS - removing FEND at start and end
            kiss_frame = data #change of variable for data: data -> kiss_frame
            kiss_frame.delete_at(0) #remove FEND at start at data
            kiss_frame.delete_at(-1) #remove FEND at end of data
            #KISS - FESC and TFEND replacement
            kiss_frame = replace_kiss_r("FESC", kiss_frame) #FESC + TFESC -> FESC
            kiss_frame = replace_kiss_r("FEND", kiss_frame) #FESC + TFEND -> FEND
            #KISS - command and port index
            kiss_command = kiss_frame.delete_at(0) #KISS command byte contains command nibble + port index nibble: C1 C2 C3 C4 PI1 PI2 PI3 PI4
            cpi_test_bits = 0b00001111 #octet to isolate low nibble of octet: 0 0 0 0 1 1 1 1
            kiss_port = ((kiss_command >> 4) & cpi_test_bits[0].to_i()) #extract command nibble by right shifting KISS command byte by four, result: 0 0 0 0 C1 C2 C3 C4, and convert result to integer
            kiss_cmd = (kiss_command & cpi_test_bits[0].to_i()) #extract port index nibble from KISS command byte and convert result to integer
            if kiss_port != 0 || kiss_cmd != 0
                puts "ERROR: KISS Command Byte - KISS Port Index or KISS CMD is non-zero"
            end
            #KISS -> AX.25
            ax25_frame = kiss_frame #remaining data should be an AX.25 frame
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
                    addr_bytes.each { |byte_i|
                        iter_current += 1
                        if iter_current == 7
                            ax25_addrs.push(byte_i >> 1)
                        else
                            ax25_addrs.push((byte_i >> 1) & 0x7F)
                        end
                    }
                end
                #AX.25 - control & PID
                frame_length_mid = ax25_frame.length()
                case frame_length_mid
                when 0 then puts "ERROR: Packet insufficient length - No Control byte"
                when 1 then puts "ERROR: Packet insufficient length - No PID byte"
                when 2 then puts "ERROR: Packet insufficient length - No Payload"
                else
                    ax25_control = ax25_frame.delete_at(0) #control byte, remove it from reamining data
                    puts "ERROR: AX.25 Control Byte - Not 0x03" if ax25_control != 0x03
                    ax25_pid = ax25_frame.delete_at(0) #protocol identifier byte, remove it from remaining data
                    puts "ERROR: AX.25 PID Byte - Not 0xF0" if ax25_pid != 0xF0
                    #AX. 25 - payload
                    ax25_payload = []
                    ax25_frame.each { |byte| ax25_payload.push(byte) } #remaining data is payload
                end
            else
                puts "ERROR: Packet insufficient length - Address field length is #{ax25_frame.length()} (< 14 bytes)"
            end
        else
            puts "ERROR: Packet format - Starting or ending byte not FEND"
        end
        packet_outgoing = "#{addr_count}"
        ax25_addrs.each { |byte_i| packet_outgoing += byte_i.chr }
        ax25_payload.each { |byte_i| packet_outgoing += byte_i.chr }
        data_outgoing = packet_outgoing
        return data_outgoing
    end    

end