using System.Text;
using System.Globalization;
using System.Text.RegularExpressions;
using System.Text.Json;
namespace RayWRT.Companion;
static class RouterTools
{
 internal record Wifi(string Id,string Radio,string Band,string Ssid,string Encryption,string Key,bool Enabled,bool? Up){
  public string State=>!Enabled?"Disabled":Up==true?"Enabled":Up==false?"Enabled · offline":"Enabled · unverified";
  public override string ToString()=>Band+" · "+Ssid;
 }
 internal record Target(string Id,bool Replied,double? Average,int? Sent,int? Received,string Reason);
 internal record PingResult(List<Target> Targets){
  public int Replies=>Targets.Count(t=>t.Replied);
  public string Average=>!Targets.Any(t=>t.Average.HasValue)?"—":Targets.Where(t=>t.Average.HasValue).Average(t=>t.Average!.Value).ToString("F1",CultureInfo.InvariantCulture)+" ms";
  public int Sent=>Targets.Where(t=>t.Replied&&t.Sent.HasValue).Sum(t=>t.Sent!.Value);
  public int Received=>Targets.Where(t=>t.Replied&&t.Received.HasValue).Sum(t=>t.Received!.Value);
  public string Loss=>Sent==0?"—":(100.0*(Sent-Received)/Sent).ToString("0.##",CultureInfo.InvariantCulture)+"%";
  public string Counts=>Sent==0?"No measured probes":$"{Sent-Received}/{Sent} probes lost";
  public string Note=>Replies==15?"All 15 servers replied.":$"{15-Replies} server(s) did not reply. This does not establish connection-wide packet loss.";
  public string Details=>string.Join("\n",Targets.Select(t=>$"{t.Id}: "+(t.Average.HasValue?t.Average.Value.ToString("F1",CultureInfo.InvariantCulture)+" ms":"No reply")+" · "+(t.Sent.HasValue&&t.Sent>0?$"{t.Sent-t.Received}/{t.Sent} probes lost":t.Reason.Replace('_',' '))));
 }
 internal static Dictionary<string,string> Parse(string raw)=>raw.Split('\n').Where(x=>x.Contains('=')).Select(x=>x.TrimEnd('\r').Split('=',2)).GroupBy(x=>x[0]).ToDictionary(x=>x.Key,x=>Unquote(x.Last()[1].Trim()));
 static string Unquote(string value){var b=new StringBuilder();bool quoted=false;for(int i=0;i<value.Length;i++){char c=value[i];if(c=='\'')quoted=!quoted;else if(c=='\\'&&!quoted&&i+1<value.Length)b.Append(value[++i]);else b.Append(c);}return b.ToString();}
 internal static string Quote(string s)=>"'"+s.Replace("'","'\\''")+"'";
 internal static List<Wifi> Wireless(string raw,string? status=null){
  var d=Parse(raw);var output=new List<Wifi>();JsonDocument? runtime=null;try{if(status!=null)runtime=JsonDocument.Parse(status);}catch(JsonException){}
  try{foreach(var p in d.Where(x=>x.Key.StartsWith("wireless.")&&x.Value=="wifi-iface"&&d.GetValueOrDefault(x.Key+".mode")=="ap")){
   var id=p.Key;var r="wireless."+d.GetValueOrDefault(id+".device");if(d.GetValueOrDefault(r)!="wifi-device")continue;
   var b=d.GetValueOrDefault(r+".band");var h=d.GetValueOrDefault(r+".hwmode");var band=b=="2g"||h=="11g"||h=="11b"?"2.4 GHz":b=="5g"||h=="11a"?"5 GHz":b=="6g"?"6 GHz":"Unknown band";
   bool enabled=!Disabled(d.GetValueOrDefault(r+".disabled"))&&!Disabled(d.GetValueOrDefault(id+".disabled"));bool? up=null;
   if(runtime!=null&&runtime.RootElement.TryGetProperty(r[9..],out var radio)){up=radio.TryGetProperty("up",out var ru)&&ru.ValueKind==JsonValueKind.True;bool present=false;
    if(radio.TryGetProperty("interfaces",out var interfaces)&&interfaces.ValueKind==JsonValueKind.Array)foreach(var iface in interfaces.EnumerateArray())if((iface.TryGetProperty("section",out var section)&&section.GetString()==id[9..])||(iface.TryGetProperty("config",out var config)&&config.TryGetProperty("ssid",out var liveSsid)&&liveSsid.GetString()==d.GetValueOrDefault(id+".ssid"))){present=true;break;}up=up==true&&present;
   }
   output.Add(new(id,r,band,d.GetValueOrDefault(id+".ssid","Unnamed network"),d.GetValueOrDefault(id+".encryption","none"),d.GetValueOrDefault(id+".key",""),enabled,up));
  }}finally{runtime?.Dispose();}return output;
 }
 static bool Disabled(string? value)=>value is "1" or "true" or "yes" or "on";
 internal static string Save(Wifi w,string ssid,string password){int bytes=Encoding.UTF8.GetByteCount(ssid);if(bytes<1||bytes>32||ssid.IndexOfAny(new[]{'\n','\r','\0'})>=0)throw new Exception("SSID must contain 1–32 UTF-8 bytes, without line breaks.");
  var changed=password!=""&&password!=w.Key;
  if(changed&&!Regex.IsMatch(password,@"\A[\x20-\x7E]{8,63}\z"))throw new Exception("Use a Wi-Fi password of 8–63 printable ASCII characters.");
  if(changed&&w.Encryption!="none"&&!w.Encryption.StartsWith("psk")&&!w.Encryption.StartsWith("sae"))throw new Exception("Password editing supports WPA Personal networks only.");
  var cmd="uci set "+Quote(w.Id+".ssid="+ssid);if(changed){cmd+=" && uci set "+Quote(w.Id+".key="+password);if(w.Encryption=="none")cmd+=" && uci set "+Quote(w.Id+".encryption=psk2");}return Transaction(cmd);
 }
 internal static string Toggle(Wifi w,bool on)=>Transaction("uci set "+Quote(w.Radio+".disabled="+(on?"0":"1"))+(on?" && uci set "+Quote(w.Id+".disabled=0"):""));
 static string Transaction(string changes)=>"test -z \"$(uci changes wireless)\" || { echo 'Apply or revert pending LuCI wireless changes first.' >&2; exit 1; }; "+changes+" && uci commit wireless || { uci revert wireless; exit 1; }; (sleep 2; wifi reload) </dev/null >/dev/null 2>&1 &";
 internal static PingResult Ping(string raw){var ids=new HashSet<string>();var targets=new List<Target>();foreach(var line in raw.Split('\n')){
  if(string.IsNullOrWhiteSpace(line))continue;var p=line.TrimEnd('\r').Split('|');if(p.Length!=9||!ids.Add(p[0]))throw new Exception("Invalid or duplicate diagnostic result.");
  double? avg=null;if(p[1]=="ok"){avg=double.Parse(p[3],CultureInfo.InvariantCulture);if(!double.IsFinite(avg.Value)||avg<0)throw new Exception("Invalid ping timing.");}else if(p[1]!="error")throw new Exception("Invalid ping status.");
  int? sent=null,received=null;if(p[7]!="NA"&&p[8]!="NA"){sent=int.Parse(p[7],CultureInfo.InvariantCulture);received=int.Parse(p[8],CultureInfo.InvariantCulture);if(sent<0||sent>4||received<0||received>sent)throw new Exception("Invalid ping probe counts.");}
  if(avg.HasValue&&(!received.HasValue||received==0))throw new Exception("Missing ping probe counts.");targets.Add(new(p[0],received>0,avg,sent,received,p[6]));
 }if(targets.Count!=15)throw new Exception("Expected results from all 15 diagnostic targets.");return new(targets);}
 internal static string PingSummary(string raw){var p=Ping(raw);return $"Average ping  {p.Average}\n{p.Replies}/15 replies · Packet loss {p.Loss} ({p.Counts})\n{p.Note}";}
 internal const string Reboot="(sleep 2; reboot) </dev/null >/dev/null 2>&1 &";
}
