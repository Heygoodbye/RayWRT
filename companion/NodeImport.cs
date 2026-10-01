using System.IO;
using System.Text.RegularExpressions;
namespace RayWRT.Companion;
static class NodeImport
{
 public static void Validate(string mode,string link,string name,string id="")
 {
  if(name.Length>80 || name.Any(char.IsControl))throw new Exception("Name must be at most 80 characters.");
  if((mode=="update" || mode=="delete")) {if(!Regex.IsMatch(id,@"^(?:[A-Za-z0-9_]+|@(?:subscribe_list|nodes)\[[0-9]+\])$"))throw new Exception("Invalid subscription identifier.");return;}
  if(link.Length>16384 || link.Any(char.IsWhiteSpace))throw new Exception("Paste one complete link without spaces.");
  if(mode=="subscription") {if(!Uri.TryCreate(link,UriKind.Absolute,out var uri)||!(uri.Scheme=="http"||uri.Scheme=="https")||string.IsNullOrEmpty(uri.Host))throw new Exception("Enter an HTTP or HTTPS subscription URL.");}
  else if(!Regex.IsMatch(link,@"^(ss|ssr|vmess|vless|trojan|hysteria|hysteria2|hy2|tuic|socks|socks5|http|https|naive\+https)://.+$",RegexOptions.IgnoreCase))throw new Exception("Enter a supported node share link.");
 }
 public static string Command(string script,string mode,string link,string name,string id="")
 {
  Validate(mode,link,name,id);
  string Q(string s)=>"'"+s.Replace("'","'\\''")+"'";
  var body="umask 077\nmkdir /tmp/raywrt-import.lock 2>/dev/null || { echo 'Another RayWRT import is running.' >&2; exit 1; }\ntrap 'rm -f /tmp/raywrt-import.lock/import.lua; rmdir /tmp/raywrt-import.lock' EXIT\ncat > /tmp/raywrt-import.lock/import.lua <<'RAYWRT_LUA'\n"+script.TrimStart('\uFEFF')+"\nRAYWRT_LUA\nlua /tmp/raywrt-import.lock/import.lua \"$@\"";
  return "sh -c "+Q(body)+" raywrt-node-import "+Q(mode)+" "+Q(link)+" "+Q(name)+" "+Q(id);
 }
}


