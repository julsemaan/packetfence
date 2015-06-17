import dpkt,pcap
import construct.protocols.layer3.dhcpv6
import six
import struct
import sys
import MySQLdb
import ConfigParser
import httplib,urllib
import json

vendors = []
enterprises = []
fingerprints = [] 

def clean_mac(mac_addr):
    s = list()
    for i in range(12/2) :
        s.append( mac_addr[i*2:i*2+2] )
    r = ":".join(s)  
    return r

class DHCPv6Sniffer:
    def __init__(self,interface):
        self.pc = pcap.pcap(name=interface)
        self.pc.setfilter('port 547')

    def start(self):
        print 'listening on %s: %s' % (self.pc.name, self.pc.filter)
        self.pc.loop(0,self.packet_handler)

    def packet_handler(self,ts,pkt):
        global vendors
        global enterprises
        global fingerprints
        eth=dpkt.ethernet.Ethernet(pkt) 
        if eth.type!=dpkt.ethernet.ETH_TYPE_IP6:
           return
    
        ip=eth.data

        src_mac = clean_mac(eth.src.encode('hex'))
    
        message = construct.protocols.layer3.dhcpv6.dhcp_message.parse(ip.data.data)
        #print message
    
        vendor = ''
        enterprise = ''
        fingerprint = ''
        for option in message.options:
            if option.code == 'OPTION_VENDOR_CLASS':
                vendor = option.data[6:]
                enterprise =  int("0x"+option.data[0:4].encode('hex'),0)
    
            elif option.code == 'OPTION_ORO':
                ordered = [str(int("0x"+option.data[i:i+2].encode('hex'),0)) for i in range(0, len(option.data), 2)]
                fingerprint = ",".join(ordered)
    
        if hasattr(self, 'callback'):
            self.callback(src_mac,fingerprint,vendor,enterprise)

        if fingerprint not in fingerprints:
            fingerprints.append(fingerprint)
            print "Found Fingerprint", fingerprint
        if vendor not in vendors:
            vendors.append(vendor)
            print "Found Vendor", vendor
        if enterprise not in enterprises:
            enterprises.append(enterprise)
            print "Found Enterprise", enterprise

class PFDB:
    def __init__(self):
        config = ConfigParser.RawConfigParser()
        config.read('/usr/local/pf/conf/pf.conf')
        try:
            self.username = config.get('database', 'user')
        except:
            self.username = 'pf'
        try:
            self.db_name = config.get('database', 'db')
        except:
            self.db_name = 'pf'

        self.password = config.get('database', 'pass')

        self.db = MySQLdb.connect(host="localhost", # your host, usually localhost
                     user=self.username, # your username
                      passwd=self.password, # your password
                      db=self.db_name) # name of the data base

    def get_node_info(self,mac):
        cursor = self.db.cursor()
        cursor.execute("SELECT mac,dhcp_fingerprint,user_agent from node where mac=%s", (mac,))

        dhcp_fingerprint = ''
        user_agent = ''
        for row in cursor.fetchall() :
            dhcp_fingerprint = row[1]
            user_agent = row[2]

        return {'dhcp_fingerprint':dhcp_fingerprint,'user_agent':user_agent}

class NodeProcessor:
    def __init__(self,dhcpv6_sniffer,fingerbank_key):
        self.dhcpv6_sniffer = dhcpv6_sniffer
        self.dhcpv6_sniffer.callback = self.new_dhcpv6_info
        self.fingerbank_key = fingerbank_key
    
    def new_dhcpv6_info(self, mac,fingerprint, vendor, enterprise):
        db = PFDB()
        info = db.get_node_info(mac)
        node = {
          'dhcp6_enterprise'  : enterprise,
          'dhcp6_fingerprint' : fingerprint,
          'dhcp_vendor'       : vendor,
          'dhcp_fingerprint'  : info['dhcp_fingerprint'],
          'user_agent'        : info['user_agent'],
          'mac'               : mac,
        }
        self.inform_fingerbank(node)

    def inform_fingerbank(self,node):
        params = json.dumps(node) 
        conn = httplib.HTTPSConnection("fingerbank.inverse.ca")
        headers = {"Content-type": "application/json",
                    "Accept": "*/*"}
        path = "/api/v1/combinations/interogate?key=%s" % self.fingerbank_key
        conn.request("GET", path, params,headers)
        response = conn.getresponse()
        if response.status != 200 and response.status != 404:
            print response.status

if __name__ == "__main__":
    sniffer = DHCPv6Sniffer(sys.argv[1])
    processor = NodeProcessor(sniffer,sys.argv[2])
    processor.dhcpv6_sniffer.start()
