import io.github.heygoodbye.raywrt.*;
import java.util.*;
public final class SshTest {
 public static void main(String[] args)throws Exception {
  Map<String,String> pins=new HashMap<>();int[] prompts={0};boolean[] accept={true};
  RouterClient.Trust trust=new RouterClient.Trust(){public String stored(String h){return pins.get(h);}public boolean confirm(String h,String f){prompts[0]++;return accept[0] && f.startsWith("SHA256:");}public void save(String h,String f){pins.put(h,f);}};
  try(RouterClient c=new RouterClient()){
   c.connect("127.0.0.1","root","fixture",trust);check(c.connected(),"SSH authentication");check(c.command("printf fixture-ok").equals("fixture-ok"),"remote command round trip");RouterModel m=new RouterModel(c.command("uci -q show passwall2; uci -q show network; true"));check(m.nodes.size()==3 && m.tunnelIds.size()==2,"router configuration retrieval");c.command("uci set "+RouterModel.quote(m.global+".node=node_de")+" && uci commit passwall2 && /etc/init.d/passwall2 restart");m=new RouterModel(c.command("uci -q show passwall2; uci -q show network; true"));check(m.nodes.get(1).active,"node switching");try{c.command("exit 7");throw new AssertionError("exit status ignored");}catch(java.io.IOException expected){check(expected.getMessage().contains("Expected fixture failure"),"stderr propagated");}
   c.close();c.connect("127.0.0.1","root","fixture",trust);check(prompts[0]==1,"known identity needs no second prompt");c.close();pins.put("127.0.0.1","SHA256:wrong");accept[0]=false;try{c.connect("127.0.0.1","root","fixture",trust);throw new AssertionError("Changed host key accepted");}catch(Exception expected){check(!c.connected(),"host key mismatch rejected");}accept[0]=true;c.connect("127.0.0.1","root","fixture",trust);check(c.connected() && !pins.get("127.0.0.1").equals("SHA256:wrong"),"replacement identity accepted and saved");
  }
  System.out.println("PASS: SSH login, commands, node change, errors, and identity pinning");
 }
 static void check(boolean okay,String message){if(!okay)throw new AssertionError(message);}
}

