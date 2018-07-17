
#Server for VCCSender & COSMOS

#Require
require "socket"

#Input
ip_addr = "127.0.0.1" #"192.168.1.134"
port_num = 8000
class Server
    def initialize(ip, port)
        puts ""
        @server = TCPServer.open(ip, port)
        puts "\e[1;37;7mServer established: #{@server} \e[0m"
        puts ""
        @client_count = 0
        @clients = Hash.new
        @connections = {server: @server, clients: @clients}
        run
    end

    def run
        loop {
            Thread.start(@server.accept) do |client|
                @client_count += 1
                client_name = "client_#{@client_count}"
                @connections[:clients][client_name] = client
                puts "\e[1;31mClient Established: #{client_name} : #{client}\e[0m"
                puts ""
                listen_messages(client_name, client)
            end
        }.join
    end

    def listen_messages(username, client)
        server_listen_thread = Thread.new do
            loop {
                #Updated Code below
                begin
                    msg = client.read_nonblock(65535)
                    puts "\e[1;33mIncoming Message (from #{username}): #{msg}\e[0m"
                rescue IO::WaitReadable
                    IO.select([client])
                    retry
                rescue IO::WaitWritable
                    IO.select(nil,[client])
                    retry
                end
                packet_recv = msg #new
                packet_full_size = packet_recv.bytesize
                puts "\e[1;36mPacket Recieved (from #{username}): #{packet_full_size} bytes\e[0m"
                @connections[:clients].each do |other_name, other_client|
                    unless other_name == username
                        #Updated Code below
                        data_send = packet_recv
                        data_full_size = data_send.bytesize
                        while 0 < data_send.bytesize
                            begin
                                bytes_sent = other_client.write_nonblock(data_send)
                                puts "\e[1;33mSending Message (#{username} --> #{other_name}) : #{data_send.byteslice(0...bytes_sent)}\e[0m"
                                puts "Bytes Sent: #{bytes_sent}"
                            rescue IO::WaitReadable
                                IO.select([other_clientr])
                                retry
                            rescue IO::WaitWritable
                                IO.select(nil,[other_client])
                                retry
                            end
                            data_send = data_send.byteslice(bytes_sent..-1)
                        end
                        puts "\e[1;32mPacket Sent (#{username} --> #{other_name}): #{data_full_size} bytes\e[0m"
                    end
                end
                puts ""
            }
        end
    end

end

Server.new(ip_addr, port_num)