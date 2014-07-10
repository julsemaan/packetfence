# Copyright 2012 James McCauley
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at:
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
This component is for use with the OpenFlow tutorial.

It acts as a simple hub, but can be modified to act like an L2
learning switch.

It's roughly similar to the one Brandon Heller did for NOX.
"""

from pox.core import core
import pox.openflow.libopenflow_01 as of
import time

log = core.getLogger()



class Tutorial (object):
  """
  A Tutorial object is created for each switch that connects.
  A Connection object for that switch is passed to the __init__ function.
  """
  def __init__ (self, connection):
    # Keep track of the connection to the switch so that we can
    # send it messages!
    self.connection = connection

    # This binds our PacketIn event listener
    connection.addListeners(self)

    # Use this table to keep track of which ethernet address is on
    # which switch port (keys are MACs, values are ports).
    self.mac_to_port = {}
    self.macs = {} 
    self.ports = {}

  def resend_packet (self, packet_in, out_port):
    """
    Instructs the switch to resend a packet that it had sent to us.
    "packet_in" is the ofp_packet_in object the switch had sent to the
    controller due to a table-miss.
    """
    msg = of.ofp_packet_out()
    msg.data = packet_in

    # Add an action to send to the specified port
    action = of.ofp_action_output(port = out_port)
    msg.actions.append(action)

    # Send message to switch
    self.connection.send(msg)

  def learn_new_mac (self, packet, packet_in):
    if not self.macs.has_key(str(packet.src)):
        from pprint import pprint
        #pprint (vars(packet))
        log.info("I LEARNT A MAC "+str(packet.src)+" IT'S IN PORT "+str(packet_in.in_port));
        self.macs[str(packet.src)] = int(time.time()) 
        self.ports[str(packet.src)] = str(packet_in.in_port)
        return str(packet.src)
    elif (int(time.time()) - self.macs[str(packet.src)]) > 30:
        log.info("AN OLD MAC CAME BACK "+str(packet.src)+" IT'S IN PORT "+str(packet_in.in_port));
        self.macs[str(packet.src)] = int(time.time()) 
        self.ports[str(packet.src)] = str(packet_in.in_port)
        return str(packet.src)
       



  def _handle_PacketIn (self, event):
    """
    Handles packet in messages from the switch.
    """

    packet = event.parsed # This is the parsed packet data.
    if not packet.parsed:
      log.warning("Ignoring incomplete packet")
      return

    packet_in = event.ofp # The actual ofp_packet_in message.
    switch_ip = event.connection.sock.getpeername()[0]
    mac = self.learn_new_mac(packet, packet_in)
    if mac:
        port = self.ports[mac]
        if port != "1":
            self.inform_nac(str(mac), str(port), switch_ip)
    elif self.ports[str(packet.src)] != str(packet_in.in_port):
        if str(packet_in.in_port) != "1":
            log.info("MAC "+str(packet.src)+" MOVED")
            self.ports[packet.src] = packet_in.in_port
            self.inform_nac(str(packet.src), str(packet_in.in_port), switch_ip)
    from pprint import pprint
    #pprint(self.ports)

  def _authorize (self, packet, packet_in, mac, port, switch_ip):
    if port == "8":
        vlan = self.inform_nac(mac,port,switch_ip)
        log.info("Node "+mac+" should have vlan "+vlan); 

        msg = of.ofp_flow_mod()
        msg.match.dl_src = mac
        msg.match.in_port = int(port)
        msg.actions.append(of.ofp_action_vlan_vid(vlan_vid=int(vlan)))
        msg.actions.append(of.ofp_action_output(port = 1))
        self.connection.send(msg)


  def inform_nac(self, mac, port, switch_ip):
    PF_ADDRESS="127.0.0.1"
    PF_PORT="9090"
    REQUEST = '{"jsonrpc": "2.0", "id": "1", "method": "openflow_authorize", "params": {"mac": "'+mac+'", "switch_ip": "'+switch_ip+'", "port": "'+port+'"}}'
    print REQUEST 
    import sys
    import urllib
    import urllib2
    import traceback
    url="http://"+PF_ADDRESS+":"+PF_PORT+"/"

    req = urllib2.Request(url)
    req.add_header("Content-Type", "application/json-rpc")
    req.add_data(REQUEST)

    page = None
    try:
        response= urllib2.urlopen(req)
        page=response.read()
        print "Received this document from the server"
        print '-'*60
        print page
        print '-'*60
        import json
        data = json.loads(page);
        import time
        return data['result'][0]
    except:
        print "Something bad happenned when authorizing with the server"
        traceback.print_exc(file=sys.stdout)
        print '-'*60
      
    

def launch ():
  """
  Starts the component
  """
  def start_switch (event):
    log.debug("Controlling %s" % (event.connection,))
    Tutorial(event.connection)
  core.openflow.addListenerByName("ConnectionUp", start_switch)

