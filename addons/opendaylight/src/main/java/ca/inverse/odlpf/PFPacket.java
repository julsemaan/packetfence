package ca.inverse.odlpf;

import java.net.InetAddress;
import java.net.URL;
import java.net.UnknownHostException;
import java.net.HttpURLConnection;
import java.io.DataOutputStream;
import javax.net.ssl.HostnameVerifier;
import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSession;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;
import javax.xml.bind.DatatypeConverter;
import org.opendaylight.controller.sal.core.Node;
import org.opendaylight.controller.sal.core.NodeConnector;
import org.opendaylight.controller.sal.packet.Ethernet;
import org.opendaylight.controller.sal.packet.IDataPacketService;
import org.opendaylight.controller.sal.packet.IListenDataPacket;
import org.opendaylight.controller.sal.packet.IPv4;
import org.opendaylight.controller.sal.packet.TCP;
import org.opendaylight.controller.sal.packet.UDP;
import org.opendaylight.controller.sal.packet.PacketException;
import org.opendaylight.controller.sal.packet.Packet;
import org.opendaylight.controller.sal.packet.PacketResult;
import org.opendaylight.controller.sal.packet.RawPacket;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import java.io.DataOutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import javax.net.ssl.*;
import javax.xml.bind.DatatypeConverter;
import org.opendaylight.controller.sal.utils.HexEncode;
import java.io.InputStreamReader;
import java.io.BufferedReader;
import org.json.*;
import java.util.Hashtable;
import java.util.ArrayList;
import java.util.Arrays;
import java.nio.Buffer;
import java.nio.ByteBuffer;

public class PFPacket {
    private Packet packet;
    private RawPacket rawPacket;
    private PacketHandler packetHandler;

    PFPacket(RawPacket rawPacket, PacketHandler packetHandler){
        this.packetHandler = packetHandler;
        this.rawPacket = rawPacket;
        this.packet = packetHandler.getDataPacketService().decodeDataPacket(this.rawPacket);
    }

    static private InetAddress intToInetAddress(int i) {
        byte b[] = new byte[] { (byte) ((i>>24)&0xff), (byte) ((i>>16)&0xff), (byte) ((i>>8)&0xff), (byte) (i&0xff) };
        InetAddress addr;
        try {
            addr = InetAddress.getByAddress(b);
        } catch (UnknownHostException e) {
            return null;
        }
 
        return addr;
    }

    /*
     * Get a reference to the layer 4 data packet
     * Either TCP or UDP, null if other
     */
    public Packet getL4Packet(){
        if (this.packet instanceof Ethernet) {
            Ethernet ethFrame = (Ethernet) this.packet;
            Object l3Pkt = ethFrame.getPayload();

            if (l3Pkt instanceof IPv4) {
                IPv4 ipv4Pkt = (IPv4) l3Pkt;
                Object l4Datagram = ipv4Pkt.getPayload();

                if (l4Datagram instanceof UDP) {
                    UDP udpDatagram = (UDP) l4Datagram;
                    return udpDatagram;
                }
                else if(l4Datagram instanceof TCP){
                    TCP tcpDatagram = (TCP) l4Datagram;
                    return tcpDatagram;
                }
            }
        }       
        return null;
    }

    /*
     * Get a reference to the layer 3 of the packet
     * Only supports IPv4 layer 3 packets
     */
    public IPv4 getL3Packet(){
        if (this.packet instanceof Ethernet) {
            Ethernet ethFrame = (Ethernet) this.packet;
            Object l3Pkt = ethFrame.getPayload();

            if (l3Pkt instanceof IPv4) {
                IPv4 ipv4Pkt = (IPv4) l3Pkt;
                return ipv4Pkt;
            }
        }
        return null;
    }

    /*
     * Get a reference to the layer 2 of the packet
     * Only supports Ethernet packets
     */
    public Ethernet getL2Packet(){
        if (this.packet instanceof Ethernet) {
            Ethernet ethFrame = (Ethernet) this.packet;
            return ethFrame;
        }
        return null;
    }

    /*
     * Get a reference to the raw packet
     */
    public RawPacket getRawPacket(){
        return this.rawPacket;
    }

    /*
     * Get a reference to the packet (not this object but the ODL representation of the packet
     */
    public Packet getPacket(){
        return this.packet;
    }

    /*
     * Get the source port of the packet
     * Works for UDP and TCP packets
     */
    public int getSourcePort(){
        Packet p = this.getL4Packet();
        if(p instanceof UDP){
            return ((UDP)p).getSourcePort();
        }
        else if(p instanceof TCP){
            return ((TCP)p).getSourcePort();
        }
        else{
            return 0;
        }
    }

    /*
     * Get the destination port of the packet
     * Works for UDP and TCP packets
     */
    public int getDestPort(){
        Packet p = this.getL4Packet();
        if(p instanceof UDP){
            return ((UDP)p).getDestinationPort();
        }
        else if(p instanceof TCP){
            return ((TCP)p).getDestinationPort();
        }
        else{
            return 0;
        }
    }

    /*
     * Get the source MAC address as a string
     */
    public String getSourceMac(){
        return HexEncode.bytesToHexStringFormat(this.getSourceMacBytes());
    }

    /*
     * Get the destination MAC address as a string
     */
    public String getDestMac(){
        return HexEncode.bytesToHexStringFormat(this.getDestMacBytes());
    }

    /*
     * Get the source MAC address bytes array
     */
    public byte[] getSourceMacBytes(){
        return this.getL2Packet().getSourceMACAddress();
    }

    /*
     * Get the destination MAC address bytes array
     */
    public byte[] getDestMacBytes(){
        return this.getL2Packet().getDestinationMACAddress();
    }

    /*
     * Get the destination MAC address bytes array
     */
    public String getSourceIP(){
        return this.getSourceInetAddress().toString().replace("/", "");
    }

    /*
     * Get the destination IP address as a String
     */
    public String getDestIP(){
        return this.getDestInetAddress().toString().replace("/", "");
    }

    /*
     * Get the source IP address as an InetAddress
     */
    public InetAddress getSourceInetAddress(){
        return intToInetAddress(this.getL3Packet().getSourceAddress());
    }

    /*
     * Get the destination IP address as an InetAddress
     */
    public InetAddress getDestInetAddress(){
        return intToInetAddress(this.getL3Packet().getDestinationAddress());
    }

    /*
     * Get the input connector (port) of the packet. 
     */
    public NodeConnector getIncomingConnector(){
        return this.rawPacket.getIncomingNodeConnector();
    }

    /*
     * Get the input connector (port) of the packet as a String. 
     */
    public String getSourceInterface(){
        return this.getIncomingConnector().getNodeConnectorIDString();
    }

    public void fixL4Checksum(){
        // For now we set the checksum to 0
        // It doesn't work for TCP though
        Packet l4Packet = this.getL4Packet();
        if(l4Packet instanceof UDP){
            ((UDP)this.getL4Packet()).setChecksum((short)0);
        }
        else if(l4Packet instanceof TCP){
            try{
                byte[] raw_data = ((TCP)this.getL4Packet()).serialize();
                byte[] header = Arrays.copyOfRange(raw_data, 0,  ((TCP)this.getL4Packet()).getHeaderSize());
                long checksum = this.computeChecksum(raw_data, this.getL3Packet().getSourceAddress(), this.getL3Packet().getDestinationAddress());
                ((TCP)this.getL4Packet()).setChecksum((short)checksum);
            }catch(PacketException e ){e.printStackTrace();}
        }
    }

    private long computeChecksum( byte[] buf, int src, int dst ){ 
        int length = buf.length;         // nr of bytes of the tcppacket in total. 
        int pseudoHeaderLength = 12;     // nr of bytes of pseudoheader. 
        int i = 0; 
        long sum = 0; 
        long data; 

        // Set the checksum in the packet 0. 
        buf[16] = (byte)0x0;  
        buf[17] = (byte)0x0; 

        // create the pseudoheader as specified in the rfc, format: 
        // [32bit-sourceIP, 32bit-destIp, 8bit-zeroes, 8bit-protocolNr, 16bit-tcpPacketLength] 
        ByteBuffer pseudoHeaderByteBuffer = ByteBuffer.allocate( 12 ); 
        pseudoHeaderByteBuffer.putInt( src );         // src.getAddress() returns an int in big endian. 
        pseudoHeaderByteBuffer.putInt( dst );     
        pseudoHeaderByteBuffer.put( (byte)0x0 ); 
        pseudoHeaderByteBuffer.put( (byte)0x06 );     // stores the protocol number (is: 0x06) 
        pseudoHeaderByteBuffer.putShort( (short) length );         // store the length of the packet. 
        byte[] pbuf = pseudoHeaderByteBuffer.array(); 

        // loop through all 16-bit words of the psuedo header 
        int bytesLeft = pseudoHeaderLength; 
        while( bytesLeft > 0 ){ 
            // take byte i and i+1 and store them as a 2-byte value in data. 
            data = ( ((pbuf[i] << 8) & 0xFF00) | ((pbuf[i + 1]) & 0x00FF));  
            sum += data; 
             
            // If the sum has bit 17 or higher set, then discard that bit and add 1 
            if( (sum & 0xFFFFFFFF0000L) > 0 ){ 
                sum = sum & 0xFFFF;     // discard all but the 16 least significant bits. 
                sum += 1; 
            } 
            i += 2; // makes i point to the next 16 bit word 
            bytesLeft -= 2;  
        } 
                    
                    
        // loop through all 16-bit words of the TCP packet (ie. until there's only 1 or 0 bytes left). 
        bytesLeft = length; 
        i=0; 
        while( bytesLeft > 1 ){ 
            // We do do exactly the same as with the pseudo-header but then for the TCP packet bytes. 
            data = ( ((buf[i] << 8) & 0xFF00) | ((buf[i + 1]) & 0x00FF)); 
            sum += data; 

            if( (sum & 0xFFFFFFFF0000L) > 0 ){ 
                sum = sum & 0xFFFF;      
                sum += 1;      
            } 
            i += 2; 
            bytesLeft -= 2;  
        } 
                 
        // If the data has an odd number of bytes, then after adding all 16 bit words we remain with 8 bits f data. 
        // In that case the missing 8 bits is considered to be all 0's. 
        if( bytesLeft > 0 ){ // ie. there are 8 bits of data remaining but we need 16. 
            data = (buf[i] << 8 & 0xFF00); // we add 8 zero bits to get the 16 bit value we need. 
            sum += data; 
            if( (sum & 0xFFFFFFFF0000L) > 0) { 
                sum = sum & 0xFFFF; 
                sum += 1; 
            } 
        } 
        sum = ~sum;            // Flip all bits (ie. take the one's complement as stated by the rfc) 
        sum = sum & 0xFFFF;     // keep only the 16 least significant bits. 
        return sum; 
    }  



}
