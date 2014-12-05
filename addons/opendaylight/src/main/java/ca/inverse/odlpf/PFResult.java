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
import org.opendaylight.controller.sal.packet.Packet;
import org.opendaylight.controller.sal.packet.PacketResult;
import org.opendaylight.controller.sal.packet.RawPacket;
import org.opendaylight.controller.sal.flowprogrammer.Flow;
import org.opendaylight.controller.sal.match.Match;
import org.opendaylight.controller.sal.utils.Status;
import org.opendaylight.controller.sal.match.MatchType;
import org.opendaylight.controller.sal.action.*;
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
import java.util.LinkedList;
import java.util.List;
import java.net.UnknownHostException;
import java.util.Date;
 

public class PFResult {
    private static final Logger log = LoggerFactory.getLogger(PacketHandler.class);
    private static final PFConfig pfconfig = new PFConfig("/etc/packetfence.conf");
    private int seconds2live;
    private String data;
    private long createdAt;

    public PFResult(String data, int seconds2live){
        this.data = data;
        this.seconds2live = seconds2live;
        this.createdAt = System.currentTimeMillis();
    }

    public String getData(){
        if(this.isStillValid()){
            return data;
        }
        else{
            return null;
        }
    }

    public boolean isStillValid(){
        long now = System.currentTimeMillis();
        long diff = (now-this.createdAt)/1000;
        System.out.println("Data is old of : "+diff+" seconds");
        if(diff < seconds2live){
            return true;
        }
        else{
            return false;
        }
    }

}
