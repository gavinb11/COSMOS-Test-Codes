#KISS WRITE PROTOCOL TEST CODE

require 'Ax25_Write_Test' #FOR TEST ONLY

class KissWriteProtocol < Ax25WriteProtocol
    FEND = "\xC0".bytes[0]
    FESC = "\xDB".bytes[0]
    TFEND = "\xDC".bytes[0]
    TFESC = "\xDD".bytes[0]
    FEND_ARR = "\xC0".bytes
    KISS_COMMAND_ARR = "\x00".bytes

    def replace_kiss_w(type_replace, data)
        if type_replace == "FESC" #FESC + TFESC -> FESC
            byte_curr = FESC
            byte_repl = FESC + TFESC
        elsif type_replace == "FEND" #FESC + TFEND -> FEND
            byte_curr = FEND
            byte_repl = FESC + TFEND
        else
            puts "KISS WRITE ERROR: Invalid Replacement Type (valid replacement types: 'FESC' or 'FEND' (strings))"
        end
        check_w = data.include?(byte_curr)
        index_w = 0
        count_w = 0
        while check_w == true
            if count_w == 0
                index_w = data.index(byte_curr)
            else
                index_w += 1
                index_w += data[index_w..-1].index(byte_curr)
            end
            data = data[0...index_w] + byte_repl + data[(index_w + 1)..-1]
            check_w = data[(index_w + 2)..-1].include?(byte_curr)
            count_w += 1
        end
        return data
    end

    def write_data(payload)
        payload_out = payload.bytes
        payload_out = replace_kiss_w("FESC", payload_out)
        payload_out = replace_kiss_w("FEND", payload_out)
        kiss_frame = FEND_ARR + KISS_COMMAND_ARR + payload_out + FEND_ARR
        packet_send = kiss_frame
        kiss_frame_st = kiss_frame.pack("C*")
        data_send = kiss_frame_st
        return data_send
    end

end