package io.github.heygoodbye.raywrt;

import java.net.InetAddress;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.regex.*;

public final class WireGuardImport {
 private static void check(boolean ok,String message)throws Exception{if(!ok)throw new Exception(message);}
 private static String q(String s){return "'"+s.replace("'","'\\''")+"'";}
 private static boolean key(String value){return value.matches("[A-Za-z0-9+/]{43}=");}
 private static Map<String,String> fields(boolean iface){Map<String,String> result=new LinkedHashMap<>();String[] names=iface?new String[]{"PrivateKey","Address","DNS","MTU","ListenPort"}:new String[]{"PublicKey","PresharedKey","AllowedIPs","Endpoint","PersistentKeepalive"};for(String name:names)result.put(name,"");return result;}
 private static int number(String value,String label,int min,int max)throws Exception{try{int n=Integer.parseInt(value);check(n>=min&&n<=max,"Invalid "+label+".");return n;}catch(NumberFormatException e){throw new Exception("Invalid "+label+".");}}
 private static List<String> ipList(String value,String label,boolean cidr)throws Exception{
  check(value!=null&&!value.trim().isEmpty(),"Missing "+label+".");List<String> result=new ArrayList<>();
  for(String source:value.split(",",-1)){String item=source.trim();String[] parts=item.split("/",-1);check(parts.length==(cidr?2:1),"Invalid "+label+".");
   check(parts[0].matches("[0-9.]+")||parts[0].matches("[0-9A-Fa-f:]+"),"Invalid "+label+".");
   InetAddress address;try{address=InetAddress.getByName(parts[0]);}catch(Exception e){throw new Exception("Invalid "+label+".");}
   if(cidr)number(parts[1],label,0,address.getAddress().length==4?32:128);result.add(item);
  }return result;
 }
 private static void set(StringBuilder b,String section,String option,String value){b.append("uci set ").append(q("network."+section+"."+option+"="+value)).append(" || exit 1\n");}
 private static void add(StringBuilder b,String section,String option,String value){b.append("uci add_list ").append(q("network."+section+"."+option+"="+value)).append(" || exit 1\n");}
 public static String command(String name,String config)throws Exception{
  check(name.matches("[a-z][a-z0-9_]{0,14}"),"Use up to 15 lowercase letters, numbers or underscores for the interface name.");
  int size=config.getBytes(StandardCharsets.UTF_8).length;check(size>0&&size<=65536,"Paste a WireGuard .conf file up to 64 KB.");
  Map<String,String> iface=null,current=null;List<Map<String,String>> peers=new ArrayList<>();
  for(String source:config.split("\n",-1)){String line=source.trim();if(line.isEmpty()||line.startsWith("#")||line.startsWith(";"))continue;
   if(line.equals("[Interface]")){check(iface==null,"Only one [Interface] is supported.");iface=fields(true);current=iface;continue;}
   if(line.equals("[Peer]")){check(iface!=null,"[Interface] must come first.");current=fields(false);peers.add(current);continue;}
   check(current!=null,"Expected [Interface] section.");int equal=line.indexOf('=');check(equal>0&&equal<line.length()-1,"Invalid configuration line.");String key=line.substring(0,equal).trim(),value=line.substring(equal+1).trim();
   check(key.matches("[A-Za-z]+")&&current.containsKey(key)&&current.get(key).isEmpty()&&!value.isEmpty()&&value.chars().noneMatch(c->Character.isISOControl((char)c)),"Unsupported or repeated WireGuard setting: "+key);current.put(key,value);
  }
  check(iface!=null&&key(iface.get("PrivateKey")),"Invalid private key.");List<String> addresses=ipList(iface.get("Address"),"Address",true);
  List<String> dns=iface.get("DNS").isEmpty()?Collections.emptyList():ipList(iface.get("DNS"),"DNS",false);
  if(!iface.get("MTU").isEmpty())number(iface.get("MTU"),"MTU",576,9000);
  if(!iface.get("ListenPort").isEmpty())number(iface.get("ListenPort"),"ListenPort",1,65535);
  check(!peers.isEmpty(),"At least one [Peer] is required.");
  StringBuilder b=new StringBuilder("umask 077\ncommand -v uci >/dev/null 2>&1 || { echo 'OpenWrt UCI is required.' >&2; exit 1; }\nmkdir /tmp/raywrt-wg-import.lock 2>/dev/null || { echo 'Another WireGuard import is running.' >&2; exit 1; }\nsuccess=0\nstaged=0\ncleanup() { if [ \"$staged\" = 1 ] && [ \"$success\" != 1 ]; then uci -q revert network; uci -q revert firewall; fi; rmdir /tmp/raywrt-wg-import.lock; }\ntrap cleanup EXIT\n");
  b.append("[ -z \"$(uci changes network)\" ] && [ -z \"$(uci changes firewall)\" ] || { echo 'Apply pending Network and Firewall changes in LuCI first.' >&2; exit 1; }\n");
  b.append("! uci -q get ").append(q("network."+name)).append(" >/dev/null 2>&1 || { echo 'An interface with this name already exists.' >&2; exit 1; }\n");
  b.append("zone=$(uci -q show firewall | sed -n \"s/^firewall\\.\\(.*\\)\\.name='wan'$/\\1/p\")\n[ -n \"$zone\" ] || { echo 'WAN firewall zone was not found.' >&2; exit 1; }\n");
  b.append("[ \"$(printf '%s\\n' \"$zone\" | wc -l)\" -eq 1 ] || { echo 'Multiple WAN firewall zones found.' >&2; exit 1; }\nstaged=1\n");
  b.append("uci set ").append(q("network."+name+"=interface")).append(" || exit 1\n");set(b,name,"proto","wireguard");set(b,name,"private_key",iface.get("PrivateKey"));set(b,name,"disabled","1");
  for(String address:addresses)add(b,name,"addresses",address);for(String server:dns)add(b,name,"dns",server);
  if(!iface.get("MTU").isEmpty())set(b,name,"mtu",iface.get("MTU"));if(!iface.get("ListenPort").isEmpty())set(b,name,"listen_port",iface.get("ListenPort"));
  for(int i=0;i<peers.size();i++){
   Map<String,String> peer=peers.get(i);check(key(peer.get("PublicKey")),"Invalid peer public key.");if(!peer.get("PresharedKey").isEmpty())check(key(peer.get("PresharedKey")),"Invalid preshared key.");List<String> allowed=ipList(peer.get("AllowedIPs"),"AllowedIPs",true);
   String host=null,port=null;if(!peer.get("Endpoint").isEmpty()){Matcher m=Pattern.compile("(?:\\[([0-9A-Fa-f:]+)\\]|([A-Za-z0-9._-]+)):(\\d+)").matcher(peer.get("Endpoint"));check(m.matches(),"Invalid Endpoint.");host=m.group(1)!=null?m.group(1):m.group(2);port=Integer.toString(number(m.group(3),"Endpoint",1,65535));}
   if(!peer.get("PersistentKeepalive").isEmpty())number(peer.get("PersistentKeepalive"),"PersistentKeepalive",0,65535);
   String peerId="raywrt_"+name+"_"+(i+1);b.append("! uci -q get ").append(q("network."+peerId)).append(" >/dev/null 2>&1 || { echo 'A peer section with this name already exists.' >&2; exit 1; }\n");
   b.append("uci set ").append(q("network."+peerId+"=wireguard_"+name)).append(" || exit 1\n");set(b,peerId,"public_key",peer.get("PublicKey"));set(b,peerId,"route_allowed_ips","1");
   if(!peer.get("PresharedKey").isEmpty())set(b,peerId,"preshared_key",peer.get("PresharedKey"));if(host!=null){set(b,peerId,"endpoint_host",host);set(b,peerId,"endpoint_port",port);}
   if(!peer.get("PersistentKeepalive").isEmpty())set(b,peerId,"persistent_keepalive",peer.get("PersistentKeepalive"));for(String item:allowed)add(b,peerId,"allowed_ips",item);
  }
  b.append("uci add_list \"firewall.$zone.network=").append(name).append("\" || exit 1\nuci commit network || { echo 'Could not save network configuration.' >&2; exit 1; }\nuci commit firewall || { echo 'Network saved, but WAN firewall assignment failed. Inspect LuCI before retrying.' >&2; exit 1; }\nsuccess=1\nprintf '%s\\n' 'WireGuard interface saved in WAN zone. Press Connect to activate it.'");
  return "sh -c "+q(b.toString());
 }
}
