import socket
import struct

def cidr_to_netmask(cidr_list):
    result = []
    for cidr in cidr_list:
        network, net_bits = cidr.split('/')
        host_bits = 32 - int(net_bits)
        netmask = socket.inet_ntoa(struct.pack('!I', (1 << 32) - (1 << host_bits)))
        result.append((network, netmask))
    print(result)



