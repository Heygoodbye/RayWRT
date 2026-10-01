package io.github.heygoodbye.raywrt;
import java.util.*;

public final class RouterTools {
 public static final class Wifi {
  public final String id,radio,band,ssid,encryption,key; public final boolean enabled; public final Boolean up;
  Wifi(String id,String radio,String band,String ssid,String encryption,String key,boolean enabled,Boolean up){this.id=id;this.radio=radio;this.band=band;this.ssid=ssid;this.encryption=encryption;this.key=key;this.enabled=enabled;this.up=up;}
  public String state(){return !enabled?"Disabled":Boolean.TRUE.equals(up)?"Enabled":Boolean.FALSE.equals(up)?"Enabled · offline":"Enabled · unverified";}
  public String toString(){return band+" · "+ssid;}
 }
 public static List<Wifi> wireless(String raw){
  Map<String,String>d=RouterModel.parse(raw);List<Wifi> out=new ArrayList<>();
  for(Map.Entry<String,String> p:d.entrySet())if(p.getKey().startsWith("wireless.")&&p.getValue().equals("wifi-iface")&&"ap".equals(d.get(p.getKey()+".mode"))){
   String id=p.getKey(),r="wireless."+d.get(id+".device");if(!"wifi-device".equals(d.get(r)))continue;
   String b=d.get(r+".band"),h=d.get(r+".hwmode");String band="2g".equals(b)||"11g".equals(h)||"11b".equals(h)?"2.4 GHz":"5g".equals(b)||"11a".equals(h)?"5 GHz":"6g".equals(b)?"6 GHz":"Unknown band";
   out.add(new Wifi(id,r,band,d.getOrDefault(id+".ssid","Unnamed network"),d.getOrDefault(id+".encryption","none"),d.getOrDefault(id+".key",""),!disabled(d.get(r+".disabled"))&&!disabled(d.get(id+".disabled")),null));
  }return out;
 }
 static boolean disabled(String v){return "1".equals(v)||"true".equals(v)||"yes".equals(v)||"on".equals(v);}
 public static List<Wifi> runtime(List<Wifi> source,Map<String,Boolean> live){List<Wifi> result=new ArrayList<>();for(Wifi w:source)result.add(new Wifi(w.id,w.radio,w.band,w.ssid,w.encryption,w.key,w.enabled,live.get(w.id)));return result;}
 public static String save(Wifi w,String ssid,String password){
  int size=ssid.getBytes(java.nio.charset.StandardCharsets.UTF_8).length;if(size<1||size>32||ssid.indexOf('\n')>=0||ssid.indexOf('\r')>=0||ssid.indexOf(0)>=0)throw new IllegalArgumentException("SSID must contain 1–32 UTF-8 bytes, without line breaks.");
  boolean changed=!password.isEmpty()&&!password.equals(w.key);
  if(changed&&(!password.matches("[\\x20-\\x7E]{8,63}")))throw new IllegalArgumentException("Use a Wi-Fi password of 8–63 printable ASCII characters.");
  if(changed&&!w.encryption.equals("none")&&!w.encryption.startsWith("psk")&&!w.encryption.startsWith("sae"))throw new IllegalArgumentException("Password editing supports WPA Personal networks only.");
  String cmd="uci set "+RouterModel.quote(w.id+".ssid="+ssid);
  if(changed){cmd+=" && uci set "+RouterModel.quote(w.id+".key="+password);if(w.encryption.equals("none"))cmd+=" && uci set "+RouterModel.quote(w.id+".encryption=psk2");}
  return transaction(cmd);
 }
 public static String toggle(Wifi w,boolean on){return transaction("uci set "+RouterModel.quote(w.radio+".disabled="+(on?"0":"1"))+(on?" && uci set "+RouterModel.quote(w.id+".disabled=0"):""));}
 private static String transaction(String changes){return "test -z \"$(uci changes wireless)\" || { echo 'Apply or revert pending LuCI wireless changes first.' >&2; exit 1; }; "+changes+" && uci commit wireless || { uci revert wireless; exit 1; }; (sleep 2; wifi reload) </dev/null >/dev/null 2>&1 &";}
 public static final class Target{
  public final String id,reason;public final Double average;public final Integer sent,received;
  Target(String id,Double average,Integer sent,Integer received,String reason){this.id=id;this.average=average;this.sent=sent;this.received=received;this.reason=reason;}
 }
 public static final class PingResult{
  public final List<Target> targets;public final int replies,sent,received;public final String average,loss,counts,note,details;
  PingResult(List<Target> ts){targets=ts;int r=0,s=0,rx=0,averages=0;double sum=0;StringBuilder detail=new StringBuilder();for(Target t:ts){
   if(t.average!=null){sum+=t.average;averages++;}if(t.received!=null&&t.received>0){r++;s+=t.sent;rx+=t.received;}
   detail.append(t.id).append(": ").append(t.average==null?"No reply":String.format(Locale.US,"%.1f ms",t.average)).append(" · ").append(t.sent!=null&&t.sent>0?(t.sent-t.received)+"/"+t.sent+" probes lost":t.reason.replace('_',' ')).append("\n");
  }replies=r;sent=s;received=rx;average=averages==0?"—":String.format(Locale.US,"%.1f ms",sum/averages);loss=s==0?"—":new java.text.DecimalFormat("0.##",java.text.DecimalFormatSymbols.getInstance(Locale.US)).format(100.0*(s-rx)/s)+"%";counts=s==0?"No measured probes":(s-rx)+"/"+s+" probes lost";
   note=r==15?"All 15 servers replied.":(15-r)+" server(s) did not reply. This does not establish connection-wide packet loss.";details=detail.toString();
  }
 }
 public static PingResult ping(String raw){Set<String> ids=new HashSet<>();List<Target> targets=new ArrayList<>();for(String line:raw.split("\\r?\\n")){
  if(line.trim().isEmpty())continue;String[]p=line.split("\\|",-1);if(p.length!=9||!ids.add(p[0]))throw new IllegalArgumentException("Invalid or duplicate diagnostic result.");
  Double avg=null;if(p[1].equals("ok")){avg=Double.parseDouble(p[3]);if(!Double.isFinite(avg)||avg<0)throw new IllegalArgumentException("Invalid ping timing.");}else if(!p[1].equals("error"))throw new IllegalArgumentException("Invalid ping status.");
  Integer sent=null,received=null;if(!p[7].equals("NA")&&!p[8].equals("NA")){sent=Integer.valueOf(p[7]);received=Integer.valueOf(p[8]);if(sent<0||sent>4||received<0||received>sent)throw new IllegalArgumentException("Invalid probe counts.");}
  if(avg!=null&&(received==null||received==0))throw new IllegalArgumentException("Missing ping probe counts.");targets.add(new Target(p[0],avg,sent,received,p[6]));
 }if(targets.size()!=15)throw new IllegalArgumentException("Expected results from all 15 diagnostic targets.");return new PingResult(targets);}
 public static String pingSummary(String raw){PingResult p=ping(raw);return "Average ping  "+p.average+"\n"+p.replies+"/15 replies · Packet loss "+p.loss+" ("+p.counts+")\n"+p.note;}
 public static final String REBOOT="(sleep 2; reboot) </dev/null >/dev/null 2>&1 &";
}
