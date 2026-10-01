using System.Net;
using System.Text;
using System.Text.RegularExpressions;

namespace RayWRT.Companion;
static class WireGuardImport
{
 static string Q(string s)=>"'"+s.Replace("'","'\\''")+"'";
 static void Check(bool ok,string message){if(!ok)throw new Exception(message);}
 static bool Key(string? value)=>value!=null && Regex.IsMatch(value,@"\A[A-Za-z0-9+/]{43}=\z");
 static string[] IpList(string? value,string label,bool cidr)
 {
  Check(!string.IsNullOrWhiteSpace(value),"Missing "+label+".");
  var items=value!.Split(',').Select(x=>x.Trim()).ToArray();
  foreach(var item in items)
  {
   var parts=item.Split('/');
   Check(parts.Length==(cidr?2:1),"Invalid "+label+".");
   Check(IPAddress.TryParse(parts[0],out var address),"Invalid "+label+".");
   if(cidr)Check(int.TryParse(parts[1],out var bits)&&bits>=0&&bits<=(address!.AddressFamily==System.Net.Sockets.AddressFamily.InterNetwork?32:128),"Invalid "+label+".");
  }
  return items;
 }
 static Dictionary<string,string> Fields(string section)=>section=="Interface"?new(){{"PrivateKey",""},{"Address",""},{"DNS",""},{"MTU",""},{"ListenPort",""}}:new(){{"PublicKey",""},{"PresharedKey",""},{"AllowedIPs",""},{"Endpoint",""},{"PersistentKeepalive",""}};
 static int Number(string? value,string label,int min,int max){Check(int.TryParse(value,out var n)&&n>=min&&n<=max,"Invalid "+label+".");return n;}
 public static string Command(string name,string config)
 {
  Check(Regex.IsMatch(name,@"\A[a-z][a-z0-9_]{0,14}\z"),"Use up to 15 lowercase letters, numbers or underscores for the interface name.");
  Check(config.Length>0&&Encoding.UTF8.GetByteCount(config)<=65536,"Paste a WireGuard .conf file up to 64 KB.");
  Dictionary<string,string>? iface=null,current=null;var peers=new List<Dictionary<string,string>>();
  foreach(var source in config.Split('\n'))
  {
   var line=source.Trim();if(line.Length==0||line[0]=='#'||line[0]==';')continue;
   if(line=="[Interface]"){Check(iface==null,"Only one [Interface] is supported.");iface=Fields("Interface");current=iface;continue;}
   if(line=="[Peer]"){Check(iface!=null,"[Interface] must come first.");current=Fields("Peer");peers.Add(current);continue;}
   Check(current!=null,"Expected [Interface] section.");var equal=line.IndexOf('=');
   Check(equal>0&&equal<line.Length-1,"Invalid configuration line.");var key=line[..equal].Trim();var value=line[(equal+1)..].Trim();
   Check(Regex.IsMatch(key,@"\A[A-Za-z]+\z")&&current!.ContainsKey(key)&&current[key].Length==0&&value.Length>0&&!value.Any(char.IsControl),"Unsupported or repeated WireGuard setting: "+key);
   current![key]=value;
  }
  Check(iface!=null&&Key(iface["PrivateKey"]),"Invalid private key.");
  var addresses=IpList(iface!["Address"],"Address",true);
  var dns=iface["DNS"].Length==0?Array.Empty<string>():IpList(iface["DNS"],"DNS",false);
  if(iface["MTU"].Length>0)Number(iface["MTU"],"MTU",576,9000);
  if(iface["ListenPort"].Length>0)Number(iface["ListenPort"],"ListenPort",1,65535);
  Check(peers.Count>0,"At least one [Peer] is required.");
  var body=new StringBuilder("umask 077\ncommand -v uci >/dev/null 2>&1 || { echo 'OpenWrt UCI is required.' >&2; exit 1; }\nmkdir /tmp/raywrt-wg-import.lock 2>/dev/null || { echo 'Another WireGuard import is running.' >&2; exit 1; }\nsuccess=0\nstaged=0\ncleanup() { if [ \"$staged\" = 1 ] && [ \"$success\" != 1 ]; then uci -q revert network; uci -q revert firewall; fi; rmdir /tmp/raywrt-wg-import.lock; }\ntrap cleanup EXIT\n");
  body.Append("[ -z \"$(uci changes network)\" ] && [ -z \"$(uci changes firewall)\" ] || { echo 'Apply pending Network and Firewall changes in LuCI first.' >&2; exit 1; }\n");
  body.Append("! uci -q get ").Append(Q("network."+name)).Append(" >/dev/null 2>&1 || { echo 'An interface with this name already exists.' >&2; exit 1; }\n");
  body.Append("zone=$(uci -q show firewall | sed -n \"s/^firewall\\.\\(.*\\)\\.name='wan'$/\\1/p\")\n[ -n \"$zone\" ] || { echo 'WAN firewall zone was not found.' >&2; exit 1; }\n");
  body.Append("[ \"$(printf '%s\\n' \"$zone\" | wc -l)\" -eq 1 ] || { echo 'Multiple WAN firewall zones found.' >&2; exit 1; }\n");
  void Set(string section,string option,string value)=>body.Append("uci set ").Append(Q("network."+section+"."+option+"="+value)).Append(" || exit 1\n");
  void Add(string section,string option,string value)=>body.Append("uci add_list ").Append(Q("network."+section+"."+option+"="+value)).Append(" || exit 1\n");
  body.Append("staged=1\nuci set ").Append(Q("network."+name+"=interface")).Append(" || exit 1\n");
  Set(name,"proto","wireguard");Set(name,"private_key",iface["PrivateKey"]);Set(name,"disabled","1");
  foreach(var address in addresses)Add(name,"addresses",address);
  foreach(var server in dns)Add(name,"dns",server);
  if(iface["MTU"].Length>0)Set(name,"mtu",iface["MTU"]);
  if(iface["ListenPort"].Length>0)Set(name,"listen_port",iface["ListenPort"]);
  for(var i=0;i<peers.Count;i++)
  {
   var peer=peers[i];Check(Key(peer["PublicKey"]),"Invalid peer public key.");
   if(peer["PresharedKey"].Length>0)Check(Key(peer["PresharedKey"]),"Invalid preshared key.");
   var allowed=IpList(peer["AllowedIPs"],"AllowedIPs",true);
   string? host=null,port=null;
   if(peer["Endpoint"].Length>0){var match=Regex.Match(peer["Endpoint"],@"\A(?:\[([0-9A-Fa-f:]+)\]|([A-Za-z0-9._-]+)):(\d+)\z");Check(match.Success,"Invalid Endpoint.");host=match.Groups[1].Success?match.Groups[1].Value:match.Groups[2].Value;port=Number(match.Groups[3].Value,"Endpoint",1,65535).ToString();}
   if(peer["PersistentKeepalive"].Length>0)Number(peer["PersistentKeepalive"],"PersistentKeepalive",0,65535);
   var peerId="raywrt_"+name+"_"+(i+1);
   body.Append("! uci -q get ").Append(Q("network."+peerId)).Append(" >/dev/null 2>&1 || { echo 'A peer section with this name already exists.' >&2; exit 1; }\n");
   body.Append("uci set ").Append(Q("network."+peerId+"=wireguard_"+name)).Append(" || exit 1\n");
   Set(peerId,"public_key",peer["PublicKey"]);Set(peerId,"route_allowed_ips","1");
   if(peer["PresharedKey"].Length>0)Set(peerId,"preshared_key",peer["PresharedKey"]);
   if(host!=null){Set(peerId,"endpoint_host",host);Set(peerId,"endpoint_port",port!);}
   if(peer["PersistentKeepalive"].Length>0)Set(peerId,"persistent_keepalive",peer["PersistentKeepalive"]);
   foreach(var value in allowed)Add(peerId,"allowed_ips",value);
  }
  body.Append("uci add_list \"firewall.$zone.network=").Append(name).Append("\" || exit 1\nuci commit network || { echo 'Could not save network configuration.' >&2; exit 1; }\nuci commit firewall || { echo 'Network saved, but WAN firewall assignment failed. Inspect LuCI before retrying.' >&2; exit 1; }\nsuccess=1\nprintf '%s\\n' 'WireGuard interface saved in WAN zone. Press Connect to activate it.'");
  return "sh -c "+Q(body.ToString());
 }
}
