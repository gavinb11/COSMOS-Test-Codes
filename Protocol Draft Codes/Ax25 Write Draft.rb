
require 'cosmos/interfaces/protocols/protocol'
require_relative 'add_sig_encrypt' #unsure

module Cosmos
    class Ax25WriteProtocol < AddSigEncrypt
        AX25_CONTROL_ARR = "\x03".bytes
        AX25_PID_ARR = "\xF0".bytes

        SAT_CALL = "WJ2XMS".bytes.to_a
        SAT_SSID = "0".bytes.to_a
        GST_CALL = "WJ2XMS".bytes.to_a
        GST_SSID = "1".bytes.to_a

        def left_shifter(data_bytes, special)
            data_bytes1 = data_bytes
            data_bytes1 = data_bytes1.collect {|byte_i| byte_i << 1}
            if special != 0
                data_bytes1[0] = data_bytes1[0] | 0x01
            end
            return data_bytes1
        end

        def write_data(payload)
            #in COSMOS dest will always be SAT and src will always be GS #or you know what I'm saying
            payload_out = payload.bytes
            dest_call = SAT_CALL
            dest_ssid = SAT_SSID
            src_call = GST_CALL
            src_ssid = GST_SSID
            dest_call_hex = left_shifter(dest_call, 0)
            dest_ssid_hex = left_shifter(dest_ssid, 0)
            src_call_hex = left_shifter(src_call, 0)
            src_ssid_hex = left_shifter(src_ssid, 1)
            addresses = dest_call_hex + dest_ssid_hex + src_call_hex + src_ssid_hex
            ax25_frame = addresses + AX25_CONTROL_ARR + AX25_PID_ARR + payload_out
            packet_send = ax25_frame
            ax25_frame_st = ax25_frame.pack("C*")
            data_send = ax25_frame_st
            return data_send
        end

    end
end
