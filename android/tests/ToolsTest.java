import io.github.heygoodbye.raywrt.*;
import java.util.*;
public class ToolsTest{
 static void check(boolean x,String m){if(!x)throw new AssertionError(m);}
 public static void main(String[]a)throws Exception{
  RouterClient.Trust trust=new RouterClient.Trust(){public String stored(String h){return null;}public void save(String h,String f){}public boolean confirm(String h,String f){return true;}};
  try(RouterClient c=new RouterClient()){
   c.connect("127.0.0.1","root","fixture",trust);String read="uci -q show passwall2; uci -q show network; uci -q show wireless; true";
   List<RouterTools.Wifi>w=RouterTools.wireless(c.command(read));check(w.size()==2&&!w.get(0).enabled&&w.get(1).enabled,"access point disabled even when radio enabled");check(w.get(1).key.equals("initial-key"),"current router password loaded");check(c.command("fixture-state").contains("\"iface0\": \"1\""),"reading configurations does not enable Wi-Fi");
   c.command(RouterTools.toggle(w.get(0),true));w=RouterTools.wireless(c.command(read));check(w.get(0).enabled&&w.get(1).enabled,"independent enable");
   c.command(RouterTools.toggle(w.get(1),false));w=RouterTools.wireless(c.command(read));check(w.get(0).enabled&&!w.get(1).enabled,"independent disable");
   check(!RouterTools.save(w.get(0),"Keep key","").contains(".key="),"blank key preserved");
   c.command(RouterTools.save(w.get(0),"Prototype WiFi","test-key-123"));w=RouterTools.wireless(c.command(read));check(w.get(0).ssid.equals("Prototype WiFi"),"SSID update");check(c.command("fixture-state").contains("test-key-123"),"key update");
   try{RouterTools.save(w.get(0),"x","short");throw new AssertionError("weak key accepted");}catch(IllegalArgumentException expected){}
   try{RouterTools.save(w.get(0),String.join("",Collections.nCopies(17,"é")),"");throw new AssertionError("UTF8 SSID accepted");}catch(IllegalArgumentException expected){}
   StringBuilder data=new StringBuilder();for(int i=0;i<15;i++)data.append("id"+i+"|ok|20|24|28|0||4|4\n");check(RouterTools.pingSummary(data.toString()).contains("15/15 replies"),"all replies");
   data=new StringBuilder();for(int i=0;i<15;i++)data.append("id"+i+(i==0?"|error|NA|NA|NA|100|timeout|4|0\n":"|ok|20|24|28|0||4|4\n"));String summary=RouterTools.pingSummary(data.toString());check(summary.contains("14/15 replies")&&summary.contains("24.0 ms")&&summary.contains("Packet loss 0%")&&summary.contains("0/56 probes lost"),"timeout average and loss");
   data=new StringBuilder();for(int i=0;i<15;i++)data.append("id"+i+"|ok|20|24|28|25||4|"+(i==0?3:4)+"\n");RouterTools.PingResult actual=RouterTools.ping(data.toString());check(actual.loss.equals("1.67%")&&actual.counts.equals("1/60 probes lost"),"actual probe counts, not averaged percentages");
   c.command(RouterTools.REBOOT);check(c.command("fixture-state").contains("\"reboots\": 1"),"reboot queued in fixture");
  }System.out.println("PASS: wireless parsing, independent radios, SSID/key edits, validation, diagnostic aggregation, fixture reboot");
 }
}
