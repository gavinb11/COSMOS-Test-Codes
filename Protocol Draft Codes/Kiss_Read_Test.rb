#KISS READ PROTOCOL TEST CODE
class KissReadProtocol
    FEND = "\xC0".bytes[0]
    FESC = "\xDB".bytes[0]
    TFEND = "\xDC".bytes[0]
    TFESC = "\xDD".bytes[0]
    KISS_PORT = 0
    KISS_CMD = 0

    def replace_kiss_r(type_replace, data_repl)
        if type_replace == "FESC" #FESC + TFESC -> FESC
            byte_curr = FESC + TFESC
            byte_repl = FESC
        elsif type_replace == "FEND" #FESC + TFEND -> FEND
            byte_curr = FESC + TFEND
            byte_repl = FEND
        else
            puts "KISS READ ERROR: Invalid Replacement Type (valid replacement types: 'FESC' or 'FEND' (strings))"
        end
        check_r = data_repl.include?(byte_curr) #check if byte stream contains byte_curr
        while check_r == true #keep replacing byte_curr as many time as that sequence of bytes appears in data stream
            index_r = data_repl.index(byte_curr) #obtain index of byte_curr
            data_repl = data_repl[0..(index_r - 1)] + byte_repl + data_repl[(index_r + 2)..-1] #replace byte_curr with byte_repl
            check_r = data_repl.include?(byte_curr) #check if byte stream contains byte_curr
        end
        return data_repl
    end

    def read_data(data_incoming)
        #SEND TO READ PROTOCOL ABOVE
        #NOT IN TEST: return super(data_incoming) if (data_incoming.length <= 0) #IF TOP LEVEL READ PROTOCOL
        data_in = data_incoming #IF TOP LEVEL READ PROTOCOL
        data = data_in.bytes() #convert data received into bytes format
        #PROCESS DATA
        #KISS PROTOCOL
        kiss_frame = data #change of variable for data: data -> kiss_frame
        if kiss_frame[0] == FEND && kiss_frame[-1] == FEND
            #KISS - removing FEND at start and end
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
            if kiss_port != KISS_PORT
                puts "KISS READ ERROR: KISS Command Byte - KISS Port Index is not #{KISS_PORT}"
            end
            if kiss_cmd != KISS_CMD
                puts "KISS READ ERROR: KISS Command Byte - KISS cmd is not #{KISS_CMD}"
            end
        else
            puts "KISS READ ERROR: Packet format - Starting or ending byte not FEND"
        end
        data_recv_new = kiss_frame.pack("C*")
        return data_recv_new
    end

end