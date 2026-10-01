using System.IO;
using System.Text.RegularExpressions;
namespace RayWRT.Companion;
public partial class MainWindow
{
 async Task ControlWireGuard(string id,bool disconnect)
 {
  if(!Regex.IsMatch(id,@"\A[A-Za-z0-9_]+\z"))throw new Exception("Invalid WireGuard interface.");
  Status.Text=disconnect?"Disconnecting WireGuard and Iran Direct routing…":"Selecting WireGuard and enabling Iran Direct routing…";
  using var resource=typeof(MainWindow).Assembly.GetManifestResourceStream("RayWRT.WireGuardControl")!;
  using var reader=new StreamReader(resource);
  string result;
  try {result=await Command("sh -c "+Quote(await reader.ReadToEndAsync())+" raywrt-wg-control "+Quote(disconnect?"disconnect":"connect")+" "+Quote(id),180);}
  finally {if(client?.IsConnected==true)await Refresh();}
  Status.Text=result.Trim();
 }
}
