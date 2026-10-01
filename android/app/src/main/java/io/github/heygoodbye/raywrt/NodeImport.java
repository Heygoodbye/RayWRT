package io.github.heygoodbye.raywrt;
import java.net.URI;
public final class NodeImport {
 public static void validate(String mode,String link,String name,String id)throws Exception{
  if(name.length()>80||name.matches("(?s).*\\p{Cntrl}.*"))throw new Exception("Name must be at most 80 characters.");
  if((mode.equals("update")||mode.equals("delete"))){if(!id.matches("(?:[A-Za-z0-9_]+|@(?:subscribe_list|nodes)\\[[0-9]+\\])"))throw new Exception("Invalid subscription identifier.");return;}
  if(link.length()>16384||link.matches("(?s).*\\s.*"))throw new Exception("Paste one complete link without spaces.");
  if(mode.equals("subscription")){try{URI u=new URI(link);if(!(u.getScheme().equals("http")||u.getScheme().equals("https"))||u.getHost()==null)throw new Exception();}catch(Exception e){throw new Exception("Enter an HTTP or HTTPS subscription URL.");}}
  else if(!link.matches("(?i)(ss|ssr|vmess|vless|trojan|hysteria|hysteria2|hy2|tuic|socks|socks5|http|https|naive\\+https)://.+"))throw new Exception("Enter a supported node share link.");
 }
 public static String command(String script,String mode,String link,String name,String id)throws Exception{
  validate(mode,link,name,id);
  String body="umask 077\nmkdir /tmp/raywrt-import.lock 2>/dev/null || { echo 'Another RayWRT import is running.' >&2; exit 1; }\ntrap 'rm -f /tmp/raywrt-import.lock/import.lua; rmdir /tmp/raywrt-import.lock' EXIT\ncat > /tmp/raywrt-import.lock/import.lua <<'RAYWRT_LUA'\n"+script.replace("\uFEFF","")+"\nRAYWRT_LUA\nlua /tmp/raywrt-import.lock/import.lua \"$@\"";
  return "sh -c "+RouterModel.quote(body)+" raywrt-node-import "+RouterModel.quote(mode)+" "+RouterModel.quote(link)+" "+RouterModel.quote(name)+" "+RouterModel.quote(id);
 }
}


