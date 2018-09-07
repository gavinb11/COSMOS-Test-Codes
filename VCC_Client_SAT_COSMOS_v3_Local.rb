
#Client for VCCSender
#these packets are not real packets

#Require
require "socket"
require_relative "kiss_ax_prot"

#Input
ip_addr = "127.0.0.1" #"192.168.1.134"
port_num = 8000

packet_r_count_sat = 0
packet_s_count_sat = 0

tlm_item_1_w = KissAxProt.new
tlm_item_2_w = KissAxProt.new
$cmd_item_r = KissAxProt.new

#TELEMETRY PACKET 1 - Downlink Science Frame
#Parameters
pktid1 = 1
pktvn = 1
gpstime = Time.now.to_i
gpsweek = 27
xpos = 11111
ypos = 222222
zpos = 3333333
posdop = 10
xvel = 242424
yvel = 25252
zvel = 2626
latdeg = -45
longdeg = 270
hordop = 20
alt = 4444
magx = 100
magy = 200
magz = 300
gyrox = 150
gyroy = 250
gyroz = 350
sunsen1 = 1000
sunsen2 = 2000
sunsen3 = 3000
sunsen4 = 4000
strainread = 7.34
#Display
puts "Packet 1:"
#puts pktid1, pktvn, gpstime, gpsweek, xpos, ypos, zpos, posdop, xvel, yvel, zvel, latdeg, longdeg, hordop, alt, magx, magy, magz, gyrox, gyroy, gyroz, sunsen1, sunsen2, sunsen3, sunsen4, strainread
#Subsections
lsp_info = [xpos, ypos, zpos, posdop].pack("Q>Q>Q>S>")
lsv_info = [xvel, yvel, zvel].pack("Q>Q>Q>")
gga_info = [latdeg, longdeg, hordop, alt].pack("l>l>S>L>")
mag_info = [magx, magy, magz].pack("S>S>S>")
gyro_info = [gyrox, gyroy, gyroz].pack("S>S>S>")
sunsen_info = [sunsen1, sunsen2, sunsen3, sunsen4].pack("S>S>S>S>")
straing_info = [strainread].pack("S>")
#Sections
gen_info1 = [pktid1, pktvn, gpstime, gpsweek].pack("CCQ>S>")
gps_info = lsp_info + lsv_info + gga_info
sens_info = mag_info + gyro_info + sunsen_info + straing_info
#Payload
pay_tlm_1 = gen_info1 + gps_info + sens_info
#Packet
$telemetry_1 = tlm_item_1_w.write_data_packet(pay_tlm_1.bytes)
puts $telemetry_1

#TELEMETRY PACKET 2 - Downlink Health Frame
#Parameters
pktid2 = 2
numreset = 56
lstresetrea = 3
antdep = 1
gpsfix = 22
sptemp1 = 100
sptemp2 = 200
sptemp3 = 300
sptemp4 = 400
sptemp5 = 500
battemp = 150
batvolt = 250
mbtemp = 350
radtemp = 450
#Display
puts "Packet 2:"
#puts pktid2, numreset, lstresetrea, antdep, gpsfix, sptemp1, sptemp2, sptemp3, sptemp4, sptemp5, battemp, batvolt, mbtemp, radtemp
#Sections
gen_info2 = [pktid2].pack("C")
reset_info = [numreset, lstresetrea].pack("Q>C")
radio_info = [antdep, gpsfix].pack("CC")
temp_info = [sptemp1, sptemp2, sptemp3, sptemp4, sptemp5, battemp, batvolt, mbtemp, radtemp].pack("L>L>L>L>L>L>L>L>L>")
#Payload
pay_tlm_2 = gen_info2 + reset_info + radio_info + temp_info
#Packet
$telemetry_2 = tlm_item_2_w.write_data_packet(pay_tlm_2.bytes)
puts $telemetry_2

$sender_c = 0

#Operations
class SatClient

    def initialize(server)
        @server = server
        @request_p = nil
        @response = nil
        listen
        send_telem
        @request_p.join
        @response.join
    end

    def listen
        packet_r_count_sat = 0
        @response = Thread.new do
            loop {
                #Updated code below
                begin
                    msg = @server.read_nonblock(65535)
                    puts "\e[1;33mMessage recieved: #{msg}\e[0m"
                rescue IO::WaitReadable
                    IO.select([@server])
                    retry
                rescue IO::WaitWritable
                    IO.select(nil,[@server])
                    retry
                end
                packet_recv = $cmd_item_r.read_data_packet(msg)
                address_num_recv = packet_recv[0]
                address_num_info = address_num_recv.chr().to_i
                packet_recv = packet_recv[1..-1]
                address_info = {}
                address_recv = packet_recv[0...(7 * address_num_info)]
                packet_recv = packet_recv[(7 * address_num_info)..-1]
                for i in 1..address_num_info
                    address_cur = address_recv[0...(7 * address_num_info)]
                    address_recv = address_recv[(7 * address_num_info)..-1]
                    case i
                    when 1 then address_info["address_dest"] = address_cur
                    when 2 then address_info["address_src"] = address_cur
                    else address_info["address_#{i}"] = address_cur
                    end
                end
                payload_recv = packet_recv
                payload_info = payload_recv.unpack("N*") #will need to update once KISS and AX25 is implemented
                cmd_info = payload_info[1]
                packet_request_info = payload_info[2]
                if cmd_info == 1
                    packet_r_count_sat += 1
                    puts "\e[1;36mPacket ##{packet_r_count_sat} Recieved: Command 1 - Request Telemetry Packet #{packet_request_info}\e[0m"
                    case packet_request_info
                    when 1 then $sender_c = 1
                    when 2 then $sender_c = 2
                    else $sender_c = 0
                    end
                end
            }
        end
    end

    def send_telem
        packet_s_count_sat = 0
        @request_p = Thread.new do
            loop {
                if $sender_c != 0
                    packet_s_count_sat += 1
                    case $sender_c
                    when 1 then packet_send = $telemetry_1
                    when 2 then packet_send = $telemetry_2
                    else packet_send = ""
                    end
                    puts "Sending Telemetry Packet ##{$sender_c}: #{packet_send}"
                    data_send = packet_send
                    data_full_size = data_send.bytesize
                    puts "Sending Packet Size: #{data_full_size}"
                    #Updated code below
                    while 0 < data_send.bytesize
                        begin
                            bytes_sent = @server.write_nonblock(data_send)
                            puts "Bytes Sent: #{bytes_sent}"
                            puts "\e[1;33mSending Message (to #{@server}) : #{data_send.byteslice(0...bytes_sent)}\e[0m"
                        rescue IO::WaitReadable
                            IO.select([@server])
                            retry
                        rescue IO::WaitReadable
                            IO.select(nil,[@server])
                            retry
                        end
                        data_send = data_send.byteslice(bytes_sent..-1)
                    end
                    puts "\e[1;32mPacket Sent (to #{@server}): #{data_full_size} bytes\e[0m"
                    $sender_c = 0
                    puts ""
                end
            }
        end
    end


end

server = TCPSocket.open(ip_addr, port_num)
SatClient.new(server)